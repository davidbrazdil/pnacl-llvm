; RUN: opt %s -minsfi-sandbox-memory-accesses -S | FileCheck %s
; XFAIL: *

; The SandboxMemoryAccess pass should fail if it encounters an unexpected 
; intrinsic such as this '@llvm.objectsize'. This mechanism protects MinSFI 
; from unsafe operations it does not handle appearing in the bitcode. 
; This could be a result of a bug in the compiler or a newly introduced
; LLVM instruction.

declare i32 @llvm.objectsize.i32(i8*, i1)

define i32 @test_unhandled_intrinsic(i8* %ptr) {
  %val = call i32 @llvm.objectsize.i32(i8* %ptr, i1 true)
  ret i32 %val
}

; CHECK: define i32 @test_unhandled_intrinsic(i8* %ptr)