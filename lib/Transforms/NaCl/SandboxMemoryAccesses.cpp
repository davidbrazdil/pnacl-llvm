//===- SandboxMemoryAccesses.cpp - XXX                                    -===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// XXX
//
//===----------------------------------------------------------------------===//

#include "llvm/Pass.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Function.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"

#define GLOBAL_MINSFI_MEMBASE "__sfi_memory_base"

using namespace llvm;

/* Things to consider:
 * - different MemBaseVar linkage (what Mark said about static/shared linking)
 * - pass MemBase around as an argument (benchmark)
 */

namespace {

  class SandboxMemoryAccesses : public FunctionPass {
    Value *MemBaseVar;
    Type *I32;
    Type *I64;

    Value *sandboxOperand(Instruction *Inst, unsigned int OpNum, Function &Func,
                          Value *MemBase);

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

  MemBaseVar = M.getOrInsertGlobal(GLOBAL_MINSFI_MEMBASE, I64);

  return true;
}

Value *SandboxMemoryAccesses::sandboxOperand(Instruction *Inst,
                                             unsigned int OpNum,
                                             Function &Func,
                                             Value *MemBase) {
  /*
   * Function must first acquire the sandbox memory region base from
   * the global variable. If this is the first sandboxed pointer, insert
   * the corresponding load instruction at the beginning of the function.
   */
  if (MemBase == NULL) {
    Instruction *MemBaseInst = new LoadInst(MemBaseVar, "mem_base");
    Func.getEntryBlock().getInstList().push_front(MemBaseInst);
    MemBase = MemBaseInst;
  }

  Value *Ptr = Inst->getOperand(OpNum);

  /*
   * Truncate the pointer to a 32-bit integer.
   * If the preceding code does 32-bit arithmetic already, such as the pattern
   * produced by ExpandGetElementPtr, reuse the final value and save two casts.
   */
  Value *TruncatedPtr;
  IntToPtrInst *Cast = dyn_cast<IntToPtrInst>(Ptr);
  bool CastFromInt32 = Cast && Cast->getOperand(0)->getType()->isIntegerTy(32);
  if (CastFromInt32)
    TruncatedPtr = Cast->getOperand(0);
  else
    TruncatedPtr = new PtrToIntInst(Ptr, I32, "", Inst);

  /* Extend the pointer value back to 64 bits and add the memory base. */
  Value *ExtendedPtr = new ZExtInst(TruncatedPtr, I64, "", Inst);
  Value *AddedBase = BinaryOperator::Create(BinaryOperator::Add, MemBase,
                                        ExtendedPtr, "", Inst);
  Value *SandboxedPtr = new IntToPtrInst(AddedBase, Ptr->getType(), "", Inst);

  /* Replace the pointer in the sandboxed operand */
  Inst->setOperand(OpNum, SandboxedPtr);

  /*
   * If the sandboxing replaced an original IntToPtr instruction and it is
   * not used any more, remove it.
   */
  if (CastFromInt32 && Cast->getNumUses() == 0)
    Cast->eraseFromParent();

  return MemBase;
}

bool SandboxMemoryAccesses::runOnFunction(Function &F) {
  Value *MemBase = NULL;

  for (Function::iterator BB = F.begin(), E = F.end(); BB != E; ++BB) {
    for (BasicBlock::iterator I = BB->begin(), E = BB->end(); I != E; ++I) {
      if (isa<LoadInst>(I))
        MemBase = sandboxOperand(I, 0, F, MemBase);
      else if (isa<StoreInst>(I))
        MemBase = sandboxOperand(I, 1, F, MemBase);
      else if (isa<MemCpyInst>(I) || isa<MemMoveInst>(I)) {
        MemBase = sandboxOperand(I, 0, F, MemBase);
        MemBase = sandboxOperand(I, 1, F, MemBase);
      } else if (isa<MemSetInst>(I))
        MemBase = sandboxOperand(I, 0, F, MemBase);
    }
  }
  return true;
}

char SandboxMemoryAccesses::ID = 0;
INITIALIZE_PASS(SandboxMemoryAccesses, "sandbox-memory-accesses",
                "Add SFI sandboxing to memory accesses",
                false, false)
