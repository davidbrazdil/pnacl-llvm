; RUN: opt %s -expand-getelementptr -minsfi-sandbox-memory-accesses -S | FileCheck %s

target datalayout = "p:32:32:32"
target triple = "le32-unknown-nacl"

; CHECK:  @__sfi_memory_base = external global i64

declare void @llvm.memcpy.p0i8.p0i8.i32(i8* nocapture, i8* nocapture readonly, i32, i32, i1)
declare void @llvm.memmove.p0i8.p0i8.i32(i8* nocapture, i8* nocapture readonly, i32, i32, i1)
declare void @llvm.memset.p0i8.i32(i8* nocapture, i8, i32, i32, i1)

declare void @llvm.memcpy.p0i8.p0i8.i64(i8* nocapture, i8* nocapture readonly, i64, i32, i1)
declare void @llvm.memmove.p0i8.p0i8.i64(i8* nocapture, i8* nocapture readonly, i64, i32, i1)
declare void @llvm.memset.p0i8.i64(i8* nocapture, i8, i64, i32, i1)

declare i32 @llvm.nacl.atomic.load.i32(i32*, i32)
declare void @llvm.nacl.atomic.store.i32(i32, i32*, i32)
declare i32 @llvm.nacl.atomic.rmw.i32(i32, i32*, i32, i32)
declare i32 @llvm.nacl.atomic.cmpxchg.i32(i32*, i32, i32, i32, i32)

declare i64 @llvm.nacl.atomic.load.i64(i64*, i32)
declare void @llvm.nacl.atomic.store.i64(i64, i64*, i32)
declare i64 @llvm.nacl.atomic.rmw.i64(i32, i64*, i64, i32)
declare i64 @llvm.nacl.atomic.cmpxchg.i64(i64*, i64, i64, i32, i32)

declare void @llvm.nacl.atomic.fence(i32)
declare void @llvm.nacl.atomic.fence.all()
declare i1 @llvm.nacl.atomic.is.lock.free(i32, i8*)

define i32 @test_load(i32* %ptr) {
  %val = load i32* %ptr
  ret i32 %val
}

; CHECK-LABEL: define i32 @test_load(i32* %ptr) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i32* %ptr to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i32* 
; CHECK-NEXT:    %val = load i32* %4
; CHECK-NEXT:    ret i32 %val
; CHECK-NEXT:  }

define void @test_store(i32* %ptr) {
  store i32 1234, i32* %ptr
  ret void
}

; CHECK-LABEL: define void @test_store(i32* %ptr) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i32* %ptr to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i32* 
; CHECK-NEXT:    store i32 1234, i32* %4
; CHECK-NEXT:    ret void
; CHECK-NEXT:  }

define void @test_memcpy_32(i8* %dest, i8* %src, i32 %len) {
  call void @llvm.memcpy.p0i8.p0i8.i32(i8* %dest, i8* %src, i32 %len, i32 4, i1 false)
  ret void
}

; CHECK-LABEL: define void @test_memcpy_32(i8* %dest, i8* %src, i32 %len) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i8* %dest to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i8* 
; CHECK-NEXT:    %5 = ptrtoint i8* %src to i32
; CHECK-NEXT:    %6 = zext i32 %5 to i64
; CHECK-NEXT:    %7 = add i64 %mem_base, %6
; CHECK-NEXT:    %8 = inttoptr i64 %7 to i8* 
; CHECK-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i32(i8* %4, i8* %8, i32 %len, i32 4, i1 false)
; CHECK-NEXT:    ret void
; CHECK-NEXT:  }

define void @test_memcpy_64(i8* %dest, i8* %src, i64 %len) {
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest, i8* %src, i64 %len, i32 4, i1 false)
  ret void
}

; CHECK-LABEL: define void @test_memcpy_64(i8* %dest, i8* %src, i64 %len) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i8* %dest to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i8* 
; CHECK-NEXT:    %5 = ptrtoint i8* %src to i32
; CHECK-NEXT:    %6 = zext i32 %5 to i64
; CHECK-NEXT:    %7 = add i64 %mem_base, %6
; CHECK-NEXT:    %8 = inttoptr i64 %7 to i8* 
; CHECK-NEXT:    %9 = trunc i64 %len to i32
; CHECK-NEXT:    %10 = zext i32 %9 to i64
; CHECK-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %4, i8* %8, i64 %10, i32 4, i1 false)
; CHECK-NEXT:    ret void
; CHECK-NEXT:  }

define void @test_memmove_32(i8* %dest, i8* %src, i32 %len) {
  call void @llvm.memmove.p0i8.p0i8.i32(i8* %dest, i8* %src, i32 %len, i32 4, i1 false)
  ret void
}

; CHECK-LABEL: define void @test_memmove_32(i8* %dest, i8* %src, i32 %len) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i8* %dest to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i8* 
; CHECK-NEXT:    %5 = ptrtoint i8* %src to i32
; CHECK-NEXT:    %6 = zext i32 %5 to i64
; CHECK-NEXT:    %7 = add i64 %mem_base, %6
; CHECK-NEXT:    %8 = inttoptr i64 %7 to i8* 
; CHECK-NEXT:    call void @llvm.memmove.p0i8.p0i8.i32(i8* %4, i8* %8, i32 %len, i32 4, i1 false)
; CHECK-NEXT:    ret void
; CHECK-NEXT:  }

define void @test_memmove_64(i8* %dest, i8* %src, i64 %len) {
  call void @llvm.memmove.p0i8.p0i8.i64(i8* %dest, i8* %src, i64 %len, i32 4, i1 false)
  ret void
}

; CHECK-LABEL: define void @test_memmove_64(i8* %dest, i8* %src, i64 %len) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i8* %dest to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i8* 
; CHECK-NEXT:    %5 = ptrtoint i8* %src to i32
; CHECK-NEXT:    %6 = zext i32 %5 to i64
; CHECK-NEXT:    %7 = add i64 %mem_base, %6
; CHECK-NEXT:    %8 = inttoptr i64 %7 to i8* 
; CHECK-NEXT:    %9 = trunc i64 %len to i32
; CHECK-NEXT:    %10 = zext i32 %9 to i64
; CHECK-NEXT:    call void @llvm.memmove.p0i8.p0i8.i64(i8* %4, i8* %8, i64 %10, i32 4, i1 false)
; CHECK-NEXT:    ret void
; CHECK-NEXT:  }

define void @test_memset_32(i8* %dest, i32 %len) {
  call void @llvm.memset.p0i8.i32(i8* %dest, i8 5, i32 %len, i32 4, i1 false)
  ret void
}

; CHECK-LABEL: define void @test_memset_32(i8* %dest, i32 %len) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i8* %dest to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i8* 
; CHECK-NEXT:    call void @llvm.memset.p0i8.i32(i8* %4, i8 5, i32 %len, i32 4, i1 false)
; CHECK-NEXT:    ret void
; CHECK-NEXT:  }

define void @test_memset_64(i8* %dest, i64 %len) {
  call void @llvm.memset.p0i8.i64(i8* %dest, i8 5, i64 %len, i32 4, i1 false)
  ret void
}

; CHECK-LABEL: define void @test_memset_64(i8* %dest, i64 %len) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i8* %dest to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i8* 
; CHECK-NEXT:    %5 = trunc i64 %len to i32
; CHECK-NEXT:    %6 = zext i32 %5 to i64
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* %4, i8 5, i64 %6, i32 4, i1 false)
; CHECK-NEXT:    ret void
; CHECK-NEXT:  }

%struct.foo = type { i32, i32 }

define i32 @test_load_elementptr(%struct.foo* %foo) {
  %y = getelementptr inbounds %struct.foo* %foo, i32 0, i32 1
  %val = load i32* %y
  ret i32 %val
}

; CHECK-LABEL: define i32 @test_load_elementptr(%struct.foo* %foo) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %gep_int = ptrtoint %struct.foo* %foo to i32
; CHECK-NEXT:    %gep = add i32 %gep_int, 4
; CHECK-NEXT:    %1 = zext i32 %gep to i64
; CHECK-NEXT:    %2 = add i64 %mem_base, %1
; CHECK-NEXT:    %3 = inttoptr i64 %2 to i32*
; CHECK-NEXT:    %val = load i32* %3
; CHECK-NEXT:    ret i32 %val
; CHECK-NEXT:  }

define i32 @test_atomic_load_32(i32* %ptr) {
  %val = call i32 @llvm.nacl.atomic.load.i32(i32* %ptr, i32 1)
  ret i32 %val
}

; CHECK-LABEL: define i32 @test_atomic_load_32(i32* %ptr) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i32* %ptr to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i32* 
; CHECK-NEXT:    %val = call i32 @llvm.nacl.atomic.load.i32(i32* %4, i32 1)
; CHECK-NEXT:    ret i32 %val
; CHECK-NEXT:  }

define i64 @test_atomic_load_64(i64* %ptr) {
  %val = call i64 @llvm.nacl.atomic.load.i64(i64* %ptr, i32 1)
  ret i64 %val
}

; CHECK-LABEL: define i64 @test_atomic_load_64(i64* %ptr) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i64* %ptr to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i64* 
; CHECK-NEXT:    %val = call i64 @llvm.nacl.atomic.load.i64(i64* %4, i32 1)
; CHECK-NEXT:    ret i64 %val
; CHECK-NEXT:  }

define void @test_atomic_store_32(i32* %ptr) {
  call void @llvm.nacl.atomic.store.i32(i32 1234, i32* %ptr, i32 1)
  ret void
}

; CHECK-LABEL: define void @test_atomic_store_32(i32* %ptr) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i32* %ptr to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i32* 
; CHECK-NEXT:    call void @llvm.nacl.atomic.store.i32(i32 1234, i32* %4, i32 1)
; CHECK-NEXT:    ret void
; CHECK-NEXT:  }

define void @test_atomic_store_64(i64* %ptr) {
  call void @llvm.nacl.atomic.store.i64(i64 1234, i64* %ptr, i32 1)
  ret void
}

; CHECK-LABEL: define void @test_atomic_store_64(i64* %ptr) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i64* %ptr to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i64* 
; CHECK-NEXT:    call void @llvm.nacl.atomic.store.i64(i64 1234, i64* %4, i32 1)
; CHECK-NEXT:    ret void
; CHECK-NEXT:  }

define i32 @test_atomic_rmw_32(i32* %ptr) {
  %val = call i32 @llvm.nacl.atomic.rmw.i32(i32 1, i32* %ptr, i32 1234, i32 1)
  ret i32 %val
}

; CHECK-LABEL: define i32 @test_atomic_rmw_32(i32* %ptr) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i32* %ptr to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i32* 
; CHECK-NEXT:    %val = call i32 @llvm.nacl.atomic.rmw.i32(i32 1, i32* %4, i32 1234, i32 1)
; CHECK-NEXT:    ret i32 %val
; CHECK-NEXT:  }

define i64 @test_atomic_rmw_64(i64* %ptr) {
  %val = call i64 @llvm.nacl.atomic.rmw.i64(i32 1, i64* %ptr, i64 1234, i32 1)
  ret i64 %val
}

; CHECK-LABEL: define i64 @test_atomic_rmw_64(i64* %ptr) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i64* %ptr to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i64* 
; CHECK-NEXT:    %val = call i64 @llvm.nacl.atomic.rmw.i64(i32 1, i64* %4, i64 1234, i32 1)
; CHECK-NEXT:    ret i64 %val
; CHECK-NEXT:  }

define i32 @test_atomic_cmpxchg_32(i32* %ptr) {
  %val = call i32 @llvm.nacl.atomic.cmpxchg.i32(i32* %ptr, i32 0, i32 1, i32 1, i32 1)
  ret i32 %val
}

; CHECK-LABEL: define i32 @test_atomic_cmpxchg_32(i32* %ptr) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i32* %ptr to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i32*
; CHECK-NEXT:    %val = call i32 @llvm.nacl.atomic.cmpxchg.i32(i32* %4, i32 0, i32 1, i32 1, i32 1)
; CHECK-NEXT:    ret i32 %val
; CHECK-NEXT:  }

define i64 @test_atomic_cmpxchg_64(i64* %ptr) {
  %val = call i64 @llvm.nacl.atomic.cmpxchg.i64(i64* %ptr, i64 0, i64 1, i32 1, i32 1)
  ret i64 %val
}

; CHECK-LABEL: define i64 @test_atomic_cmpxchg_64(i64* %ptr) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i64* %ptr to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i64*
; CHECK-NEXT:    %val = call i64 @llvm.nacl.atomic.cmpxchg.i64(i64* %4, i64 0, i64 1, i32 1, i32 1)
; CHECK-NEXT:    ret i64 %val
; CHECK-NEXT:  }

define void @test_atomic_fence() {
  call void @llvm.nacl.atomic.fence(i32 1)
  ret void
}

; CHECK-LABEL: define void @test_atomic_fence() {
; CHECK-NEXT:    call void @llvm.nacl.atomic.fence(i32 1)
; CHECK-NEXT:    ret void
; CHECK-NEXT:  }

define void @test_atomic_fence_all() {
  call void @llvm.nacl.atomic.fence.all()
  ret void
}

; CHECK-LABEL: define void @test_atomic_fence_all() {
; CHECK-NEXT:    call void @llvm.nacl.atomic.fence.all()
; CHECK-NEXT:    ret void
; CHECK-NEXT:  }

define i1 @test_atomic_is_lock_free(i8* %ptr) {
  %val = call i1 @llvm.nacl.atomic.is.lock.free(i32 4, i8* %ptr)
  ret i1 %val
}

; CHECK-LABEL: define i1 @test_atomic_is_lock_free(i8* %ptr) {
; CHECK-NEXT:    %mem_base = load i64* @__sfi_memory_base
; CHECK-NEXT:    %1 = ptrtoint i8* %ptr to i32
; CHECK-NEXT:    %2 = zext i32 %1 to i64
; CHECK-NEXT:    %3 = add i64 %mem_base, %2
; CHECK-NEXT:    %4 = inttoptr i64 %3 to i8*
; CHECK-NEXT:    %val = call i1 @llvm.nacl.atomic.is.lock.free(i32 4, i8* %4)
; CHECK-NEXT:    ret i1 %val
; CHECK-NEXT:  }
