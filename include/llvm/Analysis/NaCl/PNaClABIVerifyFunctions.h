//===- PNaClABIVerifyFunctions.h - Verify PNaCl ABI rules -----------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// Verify function-level PNaCl ABI requirements.
//
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_ANALYSIS_NACL_PNACLABIVERIFYFUNCTIONS_H
#define LLVM_ANALYSIS_NACL_PNACLABIVERIFYFUNCTIONS_H

#include "llvm/Analysis/NaCl/PNaClABIProps.h"

#include "llvm/ADT/OwningPtr.h"
#include "llvm/Analysis/NaCl.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/NaClAtomicIntrinsics.h"
#include "llvm/Pass.h"

namespace llvm {

class DataLayout;

// Checks that examine anything in the function body should be in
// FunctionPasses to make them streaming-friendly.
class PNaClABIVerifyFunctions : public FunctionPass {
  PNaClABIVerifyFunctions(const PNaClABIVerifyFunctions&) LLVM_DELETED_FUNCTION;
  void operator=(const PNaClABIVerifyFunctions&) LLVM_DELETED_FUNCTION;
 public:
  static char ID;
  PNaClABIVerifyFunctions() :
      FunctionPass(ID),
      Reporter(new PNaClABIErrorReporter),
      ReporterIsOwned(true) {
    initializePNaClABIVerifyFunctionsPass(*PassRegistry::getPassRegistry());
  }
  explicit PNaClABIVerifyFunctions(PNaClABIErrorReporter *Reporter_) :
      FunctionPass(ID),
      Reporter(Reporter_),
      ReporterIsOwned(false) {
    initializePNaClABIVerifyFunctionsPass(*PassRegistry::getPassRegistry());
  }
  virtual ~PNaClABIVerifyFunctions();
  virtual bool doInitialization(Module &M) {
    AtomicIntrinsics.reset(new NaCl::AtomicIntrinsics(M.getContext()));
    return false;
  }
  virtual void getAnalysisUsage(AnalysisUsage &Info) const {
    Info.setPreservesAll();
    Info.addRequired<DataLayout>();
  }
  bool runOnFunction(Function &F);
  virtual void print(raw_ostream &O, const Module *M) const;

private:
  const char *checkInstruction(const DataLayout *DL, const Instruction *Inst);
  PNaClABIErrorReporter *Reporter;
  bool ReporterIsOwned;
  OwningPtr<NaCl::AtomicIntrinsics> AtomicIntrinsics;
};

}

#endif  // LLVM_ANALYSIS_NACL_PNACLABIVERIFYFUNCTIONS_H
