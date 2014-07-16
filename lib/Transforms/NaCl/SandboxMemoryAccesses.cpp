//===- SandboxMemoryAccesses.cpp - Apply SFI sandboxing to used pointers  -===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This pass applies SFI sandboxing to all memory access instructions
// in the IR. Pointers are truncated to 32-bit integers and shifted to
// the 32-bit address subspace defined by base address stored in
// a global variable initialized at runtime.
//
// It is meant to be the last pass of MinSFI. Because there is
// no runtime verifier, it must be trusted to correctly sandbox all
// dereferenced pointers.
//
// Currently only works on x86_64.
//
// Sandboxed instructions:
//  - load, store
//  - memcpy, memmove, memset
//  - @llvm.nacl.atomic.load.*
//  - @llvm.nacl.atomic.store.*
//  - @llvm.nacl.atomic.rmw.*
//  - @llvm.nacl.atomic.cmpxchg.*
//
// Not applied to:
//  - inttoptr, ptrtoint
//  - ret
//
// Fails if code contains an instruction with pointer-type operands
// not listed above.
//
// Recognizes pointer arithmetic produced by ExpandGetElementPtr and
// reuses its final integer value to save target instructions. Only safe
// if runtime creates a 4GB guard page after the dedicated memory region.
//
// Does not sandbox pointers to functions invoked with Call. Assumes
// CFI will be applied afterwards.
//
//===----------------------------------------------------------------------===//

#include "llvm/Pass.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/NaClAtomicIntrinsics.h"

static const std::string GlobalMemBaseVariableName = "__sfi_memory_base";

using namespace llvm;

namespace {

class SandboxMemoryAccesses : public FunctionPass {
  Value *MemBaseVar;
  Type *I32;
  Type *I64;

  void sandboxPtrOperand(Instruction *Inst, unsigned int OpNum, Function &Func,
                         Value **MemBase);
  void sandboxLenOperand(Instruction *Inst, unsigned int OpNum, Function &Func);
  void checkDoesNotHavePointerOperands(Instruction *Inst);

public:
  static char ID;
  SandboxMemoryAccesses() : FunctionPass(ID) {
    initializeSandboxMemoryAccessesPass(*PassRegistry::getPassRegistry());
    MemBaseVar = NULL;
    I32 = I64 = NULL;
  }

  virtual bool doInitialization(Module &M);
  virtual bool runOnFunction(Function &F);
};
}

bool SandboxMemoryAccesses::doInitialization(Module &M) {
  I32 = Type::getInt32Ty(M.getContext());
  I64 = Type::getInt64Ty(M.getContext());

  MemBaseVar = M.getOrInsertGlobal(GlobalMemBaseVariableName, I64);
  return true;
}

void SandboxMemoryAccesses::sandboxPtrOperand(Instruction *Inst,
                                              unsigned int OpNum,
                                              Function &Func, Value **MemBase) {

  // Function must first acquire the sandbox memory region base from
  // the global variable. If this is the first sandboxed pointer, insert
  // the corresponding load instruction at the beginning of the function.
  if (!(*MemBase)) {
    Instruction *MemBaseInst = new LoadInst(MemBaseVar, "mem_base");
    Func.getEntryBlock().getInstList().push_front(MemBaseInst);
    *MemBase = MemBaseInst;
  }

  Value *Ptr = Inst->getOperand(OpNum);
  Value *TruncatedPtr = NULL, *AddendConst = NULL;

  // The ExpandGetElementPtr pass replaces the getelementptr instruction
  // with pointer arithmetic. If the produced pattern is recognized,
  // the pointer can be sandboxed more efficiently than in the general
  // case below.
  //
  // The recognized pattern is:
  //   %0 = add i32 %x i32 <const>
  //   %ptr = inttoptr i32 %0 to <type>*
  // and can be replaced with:
  //   %0 = zext i32 %x to i64
  //   %1 = add i64 %0 i64 %mem_base
  //   %2 = add i64 %1 i64 <const>            ; the constant is zero-extended
  //   %ptr = inttoptr i64 %2 to <type>*
  // Since this enables the code to access memory outside the dedicated
  // region, this is safe only if the region is followed by a 4GB guard page.

  Instruction *RedundantCast = NULL, *RedundantAdd = NULL;
  if (IntToPtrInst *Cast = dyn_cast<IntToPtrInst>(Ptr))
    if (BinaryOperator *Op = dyn_cast<BinaryOperator>(Cast->getOperand(0)))
      if (Op->getOpcode() == Instruction::Add)
        if (Op->getType()->isIntegerTy(32))
          if (ConstantInt *CI = dyn_cast<ConstantInt>(Op->getOperand(1)))
            if (CI->getSExtValue() > 0) {
              TruncatedPtr = Op->getOperand(0);
              AddendConst = ConstantInt::get(I64, CI->getZExtValue());
              RedundantCast = Cast;
              RedundantAdd = Op;
            }

  // If the pattern above has not been recognized, start by truncating
  // the pointer to i32.
  if (!TruncatedPtr)
    TruncatedPtr = new PtrToIntInst(Ptr, I32, "", Inst);

  // Sandbox the pointer by extending it back to 64 bits, and adding
  // the memory region base.
  Value *ExtendedPtr = new ZExtInst(TruncatedPtr, I64, "", Inst);
  Value *AddedPtr = BinaryOperator::CreateAdd(*MemBase, ExtendedPtr, "", Inst);
  if (AddendConst)
    AddedPtr = BinaryOperator::CreateAdd(AddedPtr, AddendConst, "", Inst);
  Value *SandboxedPtr = new IntToPtrInst(AddedPtr, Ptr->getType(), "", Inst);

  // Replace the pointer in the sandboxed operand
  Inst->setOperand(OpNum, SandboxedPtr);

  // Remove instructions if now dead
  if (RedundantCast && RedundantCast->getNumUses() == 0)
    RedundantCast->eraseFromParent();
  if (RedundantAdd && RedundantAdd->getNumUses() == 0)
    RedundantAdd->eraseFromParent();
}

void SandboxMemoryAccesses::sandboxLenOperand(Instruction *Inst,
                                              unsigned int OpNum,
                                              Function &Func) {
  Value *Length = Inst->getOperand(OpNum);
  if (Length->getType() == I64) {
    Value *Truncated = new TruncInst(Length, I32, "", Inst);
    Value *Extended = new ZExtInst(Truncated, I64, "", Inst);
    Inst->setOperand(OpNum, Extended);
  }
}

void SandboxMemoryAccesses::checkDoesNotHavePointerOperands(Instruction *Inst) {
  bool hasPointerOperand = false;

  // Handle Call instructions separately because they always contain
  // a pointer to the target function. Its integrity is guaranteed by CFI.
  // This pass therefore only checks the function's arguments.
  if (CallInst *Call = dyn_cast<CallInst>(Inst)) {
    int NumArguments = Call->getNumArgOperands();
    for (int i = 0; i < NumArguments; ++i)
      hasPointerOperand |= Call->getArgOperand(i)->getType()->isPointerTy();
  } else {
    int NumOperands = Inst->getNumOperands();
    for (int i = 0; i < NumOperands; ++i)
      hasPointerOperand |= Inst->getOperand(i)->getType()->isPointerTy();
  }

  if (hasPointerOperand)
    report_fatal_error("SandboxMemoryAccesses: unexpected instruction with "
                       "pointer-type operands");
}

bool SandboxMemoryAccesses::runOnFunction(Function &F) {
  Value *MemBase = NULL;

  for (Function::iterator BB = F.begin(), E = F.end(); BB != E; ++BB) {
    for (BasicBlock::iterator I = BB->begin(), E = BB->end(); I != E; ++I) {
      if (isa<LoadInst>(I)) {
        sandboxPtrOperand(I, 0, F, &MemBase);
      } else if (isa<StoreInst>(I)) {
        sandboxPtrOperand(I, 1, F, &MemBase);
      } else if (isa<MemCpyInst>(I) || isa<MemMoveInst>(I)) {
        sandboxPtrOperand(I, 0, F, &MemBase);
        sandboxPtrOperand(I, 1, F, &MemBase);
        sandboxLenOperand(I, 2, F);
      } else if (isa<MemSetInst>(I)) {
        sandboxPtrOperand(I, 0, F, &MemBase);
        sandboxLenOperand(I, 2, F);
      } else if (IntrinsicInst *IntrCall = dyn_cast<IntrinsicInst>(I)) {
        switch (IntrCall->getIntrinsicID()) {
        case Intrinsic::nacl_atomic_load:
        case Intrinsic::nacl_atomic_cmpxchg:
          sandboxPtrOperand(IntrCall, 0, F, &MemBase);
          break;
        case Intrinsic::nacl_atomic_store:
        case Intrinsic::nacl_atomic_rmw:
        case Intrinsic::nacl_atomic_is_lock_free:
          sandboxPtrOperand(IntrCall, 1, F, &MemBase);
          break;
        default:
          checkDoesNotHavePointerOperands(IntrCall);
        }
      } else if (!isa<IntToPtrInst>(I) && !isa<PtrToIntInst>(I) &&
                 !isa<ReturnInst>(I)) {
        checkDoesNotHavePointerOperands(I);
      }
    }
  }

  return true;
}

char SandboxMemoryAccesses::ID = 0;
INITIALIZE_PASS(SandboxMemoryAccesses, "minsfi-sandbox-memory-accesses",
                "Add SFI sandboxing to memory accesses", false, false)
