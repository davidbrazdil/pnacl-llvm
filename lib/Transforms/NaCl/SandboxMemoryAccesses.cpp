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
    Value *MemBase;
    Type *I32;
    Type *I64;

    Value *sandboxPtr(Value *Ptr, Instruction *InsertPt);
    void sandboxOperand(Instruction *Inst, unsigned int OpNum);

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

Value *SandboxMemoryAccesses::sandboxPtr(Value *Ptr, Instruction *InsertPt) {
  /*
   * Function must first acquire the sandbox memory region base from
   * the global variable. If this is the first sandboxed pointer, insert
   * the corresponding load instruction at the beginning of the function.
   */
  if (MemBase == NULL) {
    Function *Func = InsertPt->getParent()->getParent();
    Instruction *MemBaseInst = new LoadInst(MemBaseVar, "mem_base");
    Func->getEntryBlock().getInstList().push_front(MemBaseInst);
    MemBase = MemBaseInst;
  }

  /*
   * The pointer used by the program is truncated to a 32-bit integer,
   * then extended back to 64 bits and memory base of the sandbox added.
   */
  Value *Truncated = new PtrToIntInst(Ptr, I32, "", InsertPt);
  Value *ZExt = new ZExtInst(Truncated, I64, "", InsertPt);
  Value *Added = BinaryOperator::Create(BinaryOperator::Add, MemBase, ZExt,
                                        "", InsertPt);
  return new IntToPtrInst(Added, Ptr->getType(), "", InsertPt);
}

void SandboxMemoryAccesses::sandboxOperand(Instruction *Inst,
                                           unsigned int OpNum) {
  Inst->setOperand(OpNum, sandboxPtr(Inst->getOperand(OpNum), Inst));
}

bool SandboxMemoryAccesses::runOnFunction(Function &F) {
  MemBase = NULL;

  for (Function::iterator BB = F.begin(), E = F.end(); BB != E; ++BB) {
    for (BasicBlock::iterator I = BB->begin(), E = BB->end(); I != E; ++I) {
      if (isa<LoadInst>(I))
        sandboxOperand(I, 0);
      else if (isa<StoreInst>(I))
        sandboxOperand(I, 1);
      else if (isa<MemCpyInst>(I) || isa<MemMoveInst>(I)) {
        sandboxOperand(I, 0);
        sandboxOperand(I, 1);
      } else if (isa<MemSetInst>(I))
        sandboxOperand(I, 0);
    }
  }
  return true;
}

char SandboxMemoryAccesses::ID = 0;
INITIALIZE_PASS(SandboxMemoryAccesses, "sandbox-memory-accesses",
                "Add SFI sandboxing to memory accesses",
                false, false)
