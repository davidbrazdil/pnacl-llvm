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

#define GLOBAL_MINSFI_MEMBASE "__sfi_memory_base"

using namespace llvm;

namespace {

  class SandboxMemoryAccesses : public FunctionPass {
    Value *MemBaseVar;

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
  Type *I64 = Type::getInt64Ty(M.getContext());
  MemBaseVar = M.getOrInsertGlobal(GLOBAL_MINSFI_MEMBASE, I64);

  /* Things to consider:
   * - different MemBaseVar linkage (what Mark said about static/shared linking)
   * - pass around as an argument (benchmark)
   */

  return false;
}

bool SandboxMemoryAccesses::runOnFunction(Function &F) {
  errs() << "Hello ";
  errs().write_escaped(F.getName()) << "\n";
  return false;
}

char SandboxMemoryAccesses::ID = 0;
INITIALIZE_PASS(SandboxMemoryAccesses, "sandbox-memory-accesses",
                "Add SFI sandboxing to memory accesses",
                false, false)
