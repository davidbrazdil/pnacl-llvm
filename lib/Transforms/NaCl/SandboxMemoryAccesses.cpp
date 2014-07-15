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
// Applied on instructions:
//  - load, store
//  - memcpy, memmove, memset
//
// Recognizes pointer arithmetic produced by ExpandGetElementPtr and
// reuses its final integer value to save two casts.
//
//===----------------------------------------------------------------------===//

#include "llvm/Pass.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"

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

public:
  static char ID;
  SandboxMemoryAccesses() : FunctionPass(ID) {
    initializeSandboxMemoryAccessesPass(*PassRegistry::getPassRegistry());
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
                                              Function &Func,
                                              Value **MemBase) {

  // Function must first acquire the sandbox memory region base from
  // the global variable. If this is the first sandboxed pointer, insert
  // the corresponding load instruction at the beginning of the function.
  if (!(*MemBase)) {
    Instruction *MemBaseInst = new LoadInst(MemBaseVar, "mem_base");
    Func.getEntryBlock().getInstList().push_front(MemBaseInst);
    *MemBase = MemBaseInst;
  }

  Value *Ptr = Inst->getOperand(OpNum);

  // Truncate the pointer to a 32-bit integer.
  // If the preceding code does 32-bit arithmetic already, such as the pattern
  // produced by ExpandGetElementPtr, reuse the final value and save two casts.
  Value *TruncatedPtr;
  IntToPtrInst *Cast = dyn_cast<IntToPtrInst>(Ptr);
  bool CastFromInt32 = Cast && Cast->getOperand(0)->getType()->isIntegerTy(32);
  if (CastFromInt32)
    TruncatedPtr = Cast->getOperand(0);
  else
    TruncatedPtr = new PtrToIntInst(Ptr, I32, "", Inst);

  // Extend the pointer value back to 64 bits and add the memory base.
  Value *ExtendedPtr = new ZExtInst(TruncatedPtr, I64, "", Inst);
  Value *AddedBase = BinaryOperator::Create(BinaryOperator::Add, *MemBase,
                                            ExtendedPtr, "", Inst);
  Value *SandboxedPtr = new IntToPtrInst(AddedBase, Ptr->getType(), "", Inst);

  // Replace the pointer in the sandboxed operand
  Inst->setOperand(OpNum, SandboxedPtr);

  // If the sandboxing replaced an original IntToPtr instruction and it is
  // not used any more, remove it.
  if (CastFromInt32 && Cast->getNumUses() == 0)
    Cast->eraseFromParent();
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
      }
    }
  }

  return true;
}

char SandboxMemoryAccesses::ID = 0;
INITIALIZE_PASS(SandboxMemoryAccesses, "minsfi-sandbox-memory-accesses",
                "Add SFI sandboxing to memory accesses",
                false, false)
