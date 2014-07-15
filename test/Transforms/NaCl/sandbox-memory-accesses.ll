; RUN: opt %s -expand-getelementptr -sandbox-memory-accesses -S | FileCheck %s

target datalayout = "e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-p:32:32:32-v128:32:32"
target triple = "le32-unknown-nacl"

declare void @llvm.memcpy.p0i8.p0i8.i32(i8* nocapture, i8* nocapture readonly, i32, i32, i1)
declare void @llvm.memmove.p0i8.p0i8.i32(i8* nocapture, i8* nocapture readonly, i32, i32, i1)
declare void @llvm.memset.p0i8.i32(i8* nocapture, i8, i32, i32, i1)

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

define void @test_memcpy(i8* %dest, i8* %src) {
  call void @llvm.memcpy.p0i8.p0i8.i32(i8* %dest, i8* %src, i32 4, i32 4, i1 false)
  ret void
}

; CHECK:      define void @test_memcpy(i8* %dest, i8* %src) {
; CHECK-NEXT:   %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:   %1 = ptrtoint i8* %dest to i32
; CHECK-NEXT:   %2 = zext i32 %1 to i64
; CHECK-NEXT:   %3 = add i64 %mem_base, %2
; CHECK-NEXT:   %4 = inttoptr i64 %3 to i8* 
; CHECK-NEXT:   %5 = ptrtoint i8* %src to i32
; CHECK-NEXT:   %6 = zext i32 %5 to i64
; CHECK-NEXT:   %7 = add i64 %mem_base, %6
; CHECK-NEXT:   %8 = inttoptr i64 %7 to i8* 
; CHECK-NEXT:   call void @llvm.memcpy.p0i8.p0i8.i32(i8* %4, i8* %8, i32 4, i32 4, i1 false)
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

define void @test_memmove(i8* %dest, i8* %src) {
  call void @llvm.memmove.p0i8.p0i8.i32(i8* %dest, i8* %src, i32 4, i32 4, i1 false)
  ret void
}

; CHECK:      define void @test_memmove(i8* %dest, i8* %src) {
; CHECK-NEXT:   %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:   %1 = ptrtoint i8* %dest to i32
; CHECK-NEXT:   %2 = zext i32 %1 to i64
; CHECK-NEXT:   %3 = add i64 %mem_base, %2
; CHECK-NEXT:   %4 = inttoptr i64 %3 to i8* 
; CHECK-NEXT:   %5 = ptrtoint i8* %src to i32
; CHECK-NEXT:   %6 = zext i32 %5 to i64
; CHECK-NEXT:   %7 = add i64 %mem_base, %6
; CHECK-NEXT:   %8 = inttoptr i64 %7 to i8* 
; CHECK-NEXT:   call void @llvm.memmove.p0i8.p0i8.i32(i8* %4, i8* %8, i32 4, i32 4, i1 false)
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

define void @test_memset(i8* %dest) {
  call void @llvm.memset.p0i8.i32(i8* %dest, i8 5, i32 4, i32 4, i1 false)
  ret void
}

; CHECK:      define void @test_memset(i8* %dest) {
; CHECK-NEXT:   %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:   %1 = ptrtoint i8* %dest to i32
; CHECK-NEXT:   %2 = zext i32 %1 to i64
; CHECK-NEXT:   %3 = add i64 %mem_base, %2
; CHECK-NEXT:   %4 = inttoptr i64 %3 to i8* 
; CHECK-NEXT:   call void @llvm.memset.p0i8.i32(i8* %4, i8 5, i32 4, i32 4, i1 false)
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

%struct.foo = type { i32, i32 }

define i32 @test_load_elementptr(%struct.foo* %foo) {
  %y = getelementptr inbounds %struct.foo* %foo, i32 0, i32 1
  %val = load i32* %y
  ret i32 %val
}

; CHECK:      define i32 @test_load_elementptr(%struct.foo* %foo) {
; CHECK-NEXT:   %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:   %gep_int = ptrtoint %struct.foo* %foo to i32
; CHECK-NEXT:   %gep = add i32 %gep_int, 4
; CHECK-NEXT:   %1 = zext i32 %gep to i64
; CHECK-NEXT:   %2 = add i64 %mem_base, %1
; CHECK-NEXT:   %3 = inttoptr i64 %2 to i32*
; CHECK-NEXT:   %val = load i32* %3
; CHECK-NEXT:   ret i32 %val
; CHECK-NEXT: }
