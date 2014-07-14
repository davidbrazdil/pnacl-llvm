; RUN: opt %s -sandbox-memory-accesses -S | FileCheck %s

; CHECK: @__sfi_memory_base = external global i64

define i32 @test_load(i32* %ptr) {
  %val = load i32* %ptr
  ret i32 %val
}

; CHECK:      define i32 @test_load(i32* %ptr) {
; CHECK-NEXT:   %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:   %1 = ptrtoint i32* %ptr to i32
; CHECK-NEXT:   %2 = zext i32 %1 to i64
; CHECK-NEXT:   %3 = add i64 %mem_base, %2
; CHECK-NEXT:   %4 = inttoptr i64 %3 to i32* 
; CHECK-NEXT:   %val = load i32* %4
; CHECK-NEXT:   ret i32 %val
; CHECK-NEXT: }

define void @test_store(i32* %ptr) {
  store i32 1234, i32* %ptr
  ret void
}

; CHECK:      define void @test_store(i32* %ptr) {
; CHECK-NEXT:   %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:   %1 = ptrtoint i32* %ptr to i32
; CHECK-NEXT:   %2 = zext i32 %1 to i64
; CHECK-NEXT:   %3 = add i64 %mem_base, %2
; CHECK-NEXT:   %4 = inttoptr i64 %3 to i32* 
; CHECK-NEXT:   store i32 1234, i32* %4
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

