; RUN: opt %s -minsfi-sandbox-memory-accesses -S | FileCheck %s
; XFAIL: *

; The SandboxMemoryAccess pass should fail if it encounters an unexpected 
; instruction such as this 'atomicrmw'. This mechanism protects MinSFI 
; from unsafe operations it does not handle appearing in the bitcode. 
; This could be a result of a bug in the compiler or a newly introduced
; LLVM instruction.

define i32 @test_unhandled_instr(i32* %ptr) {
  %old = atomicrmw add i32* %ptr, i32 1 acquire
  ret i32 %old
}

; CHECK: define i32 @test_unhandled_instr(i32* %ptr)