!--------------------------------------------------------------------------------------------------!
! Copyright (C) by the DBCSR developers group - All rights reserved                                !
! This file is part of the DBCSR library.                                                          !
!                                                                                                  !
! For information on the license, see the LICENSE file.                                            !
! For further information please visit https://dbcsr.cp2k.org                                      !
! SPDX-License-Identifier: GPL-2.0+                                                                !
!--------------------------------------------------------------------------------------------------!

MODULE dbcsr_min_heap
   USE dbcsr_kinds, ONLY: int_4
#include "base/dbcsr_base_uses.f90"

   IMPLICIT NONE
   PRIVATE

   PUBLIC :: dbcsr_heap_type, keyt, valt
   PUBLIC :: dbcsr_heap_pop, dbcsr_heap_reset_node, dbcsr_heap_fill
   PUBLIC :: dbcsr_heap_new, dbcsr_heap_release
   PUBLIC :: dbcsr_heap_get_first, dbcsr_heap_reset_first

   ! Sets the types
   INTEGER, PARAMETER         :: keyt = int_4
   INTEGER, PARAMETER         :: valt = int_4

   TYPE dbcsr_heap_node
      INTEGER(KIND=keyt) :: key = -1_keyt
      INTEGER(KIND=valt) :: value = -1_valt
   END TYPE dbcsr_heap_node

   TYPE dbcsr_heap_node_e
      TYPE(dbcsr_heap_node) :: node = dbcsr_heap_node()
   END TYPE dbcsr_heap_node_e

   TYPE dbcsr_heap_type
      INTEGER :: n = -1
      INTEGER, DIMENSION(:), POINTER           :: index => NULL()
      TYPE(dbcsr_heap_node_e), DIMENSION(:), POINTER :: nodes => NULL()
   END TYPE dbcsr_heap_type

CONTAINS

   ! Lookup functions

   ELEMENTAL FUNCTION get_parent(n) RESULT(parent)
      INTEGER, INTENT(IN)                                :: n
      INTEGER                                            :: parent

      parent = INT(n/2)
   END FUNCTION get_parent

   ELEMENTAL FUNCTION get_left_child(n) RESULT(child)
      INTEGER, INTENT(IN)                                :: n
      INTEGER                                            :: child

      child = 2*n
   END FUNCTION get_left_child

   ELEMENTAL FUNCTION get_value(heap, n) RESULT(value)
      TYPE(dbcsr_heap_type), INTENT(IN)                  :: heap
      INTEGER, INTENT(IN)                                :: n
      INTEGER(KIND=valt)                                 :: value

      value = heap%nodes(n)%node%value
   END FUNCTION get_value

   ! Initialization functions

   SUBROUTINE dbcsr_heap_new(heap, n)
      TYPE(dbcsr_heap_type), INTENT(OUT)                 :: heap
      INTEGER, INTENT(IN)                                :: n

      heap%n = n
      ALLOCATE (heap%index(n))
      ALLOCATE (heap%nodes(n))
   END SUBROUTINE dbcsr_heap_new

   SUBROUTINE dbcsr_heap_release(heap)
      TYPE(dbcsr_heap_type), INTENT(INOUT)               :: heap

      DEALLOCATE (heap%index)
      DEALLOCATE (heap%nodes)
      heap%n = 0
   END SUBROUTINE dbcsr_heap_release

   SUBROUTINE dbcsr_heap_fill(heap, values)
      !! Fill heap with given values
      TYPE(dbcsr_heap_type), INTENT(INOUT)               :: heap
      INTEGER(KIND=valt), DIMENSION(:), INTENT(IN)       :: values

      INTEGER                                            :: first, i, n

      n = SIZE(values)
      DBCSR_ASSERT(heap%n >= n)

      DO i = 1, n
         heap%index(i) = i
         heap%nodes(i)%node%key = i
         heap%nodes(i)%node%value = values(i)
      END DO
      ! Sort from the last full subtree
      first = get_parent(n)
      DO i = first, 1, -1
         CALL bubble_down(heap, i)
      END DO

   END SUBROUTINE dbcsr_heap_fill

   SUBROUTINE dbcsr_heap_get_first(heap, key, value, found)
      !! Returns the first heap element without removing it.
      TYPE(dbcsr_heap_type), INTENT(INOUT)               :: heap
      INTEGER(KIND=keyt), INTENT(OUT)                    :: key
      INTEGER(KIND=valt), INTENT(OUT)                    :: value
      LOGICAL, INTENT(OUT)                               :: found

      IF (heap%n .LT. 1) THEN
         found = .FALSE.
      ELSE
         found = .TRUE.
         key = heap%nodes(1)%node%key
         value = heap%nodes(1)%node%value
      END IF
   END SUBROUTINE dbcsr_heap_get_first

   SUBROUTINE dbcsr_heap_pop(heap, key, value, found)
      !! Returns and removes the first heap element and rebalances
      !! the heap.

      TYPE(dbcsr_heap_type), INTENT(INOUT)               :: heap
      INTEGER(KIND=keyt), INTENT(OUT)                    :: key
      INTEGER(KIND=valt), INTENT(OUT)                    :: value
      LOGICAL, INTENT(OUT)                               :: found

!

      CALL dbcsr_heap_get_first(heap, key, value, found)
      IF (found) THEN
         IF (heap%n .GT. 1) THEN
            CALL dbcsr_heap_copy_node(heap, 1, heap%n)
            heap%n = heap%n - 1
            CALL bubble_down(heap, 1)
         ELSE
            heap%n = heap%n - 1
         END IF
      END IF
   END SUBROUTINE dbcsr_heap_pop

   SUBROUTINE dbcsr_heap_reset_node(heap, key, value)
      !! Changes the value of the heap element with given key and
      !! rebalances the heap.

      TYPE(dbcsr_heap_type), INTENT(INOUT)               :: heap
      INTEGER(KIND=keyt), INTENT(IN)                     :: key
      INTEGER(KIND=valt), INTENT(IN)                     :: value

      INTEGER                                            :: n, new_pos

      DBCSR_ASSERT(heap%n > 0)

      n = heap%index(key)
      DBCSR_ASSERT(heap%nodes(n)%node%key == key)
      heap%nodes(n)%node%value = value
      CALL bubble_up(heap, n, new_pos)
      CALL bubble_down(heap, new_pos)
   END SUBROUTINE dbcsr_heap_reset_node

   SUBROUTINE dbcsr_heap_reset_first(heap, value)
      !! Changes the value of the minimum heap element and rebalances the heap.
      TYPE(dbcsr_heap_type), INTENT(INOUT)               :: heap
      INTEGER(KIND=valt), INTENT(IN)                     :: value

      DBCSR_ASSERT(heap%n > 0)
      heap%nodes(1)%node%value = value
      CALL bubble_down(heap, 1)
   END SUBROUTINE dbcsr_heap_reset_first

   PURE SUBROUTINE dbcsr_heap_swap(heap, e1, e2)
      TYPE(dbcsr_heap_type), INTENT(INOUT)               :: heap
      INTEGER, INTENT(IN)                                :: e1, e2

      INTEGER(KIND=keyt)                                 :: key1, key2
      TYPE(dbcsr_heap_node)                              :: tmp_node

      key1 = heap%nodes(e1)%node%key
      key2 = heap%nodes(e2)%node%key

      tmp_node = heap%nodes(e1)%node
      heap%nodes(e1)%node = heap%nodes(e2)%node
      heap%nodes(e2)%node = tmp_node

      heap%index(key1) = e2
      heap%index(key2) = e1
   END SUBROUTINE dbcsr_heap_swap

   PURE SUBROUTINE dbcsr_heap_copy_node(heap, e1, e2)
      !! Sets node e1 to e2
      TYPE(dbcsr_heap_type), INTENT(INOUT)               :: heap
      INTEGER, INTENT(IN)                                :: e1, e2

      INTEGER(KIND=keyt)                                 :: key1, key2

      key1 = heap%nodes(e1)%node%key
      key2 = heap%nodes(e2)%node%key

      heap%nodes(e1)%node = heap%nodes(e2)%node

      heap%index(key1) = 0
      heap%index(key2) = e1
   END SUBROUTINE dbcsr_heap_copy_node

   SUBROUTINE bubble_down(heap, first)
      !! Balances a heap by bubbling down from the given element.
      TYPE(dbcsr_heap_type), INTENT(INOUT)               :: heap
      INTEGER, INTENT(IN)                                :: first

      INTEGER                                            :: e, left_child, right_child, smallest
      INTEGER(kind=valt)                                 :: left_child_value, min_value, &
                                                            right_child_value
      LOGICAL                                            :: all_done

!
      DBCSR_ASSERT(0 < first .AND. first <= heap%n)

      e = first
      all_done = .FALSE.
      ! Check whether we are finished, i.e,. whether the element to
      ! bubble down is childless.
      DO WHILE (e .LE. get_parent(heap%n) .AND. .NOT. all_done)
         ! Determines which node (current, left, or right child) has the
         ! smallest value.
         smallest = e
         min_value = get_value(heap, e)
         left_child = get_left_child(e)
         IF (left_child .LE. heap%n) THEN
            left_child_value = get_value(heap, left_child)
            IF (left_child_value .LT. min_value) THEN
               min_value = left_child_value
               smallest = left_child
            END IF
         END IF
         right_child = left_child + 1
         IF (right_child .LE. heap%n) THEN
            right_child_value = get_value(heap, right_child)
            IF (right_child_value .LT. min_value) THEN
               min_value = right_child_value
               smallest = right_child
            END IF
         END IF
         !
         CALL dbcsr_heap_swap(heap, e, smallest)
         IF (smallest .EQ. e) THEN
            all_done = .TRUE.
         ELSE
            e = smallest
         END IF
      END DO
   END SUBROUTINE bubble_down

   SUBROUTINE bubble_up(heap, first, new_pos)
      !! Balances a heap by bubbling up from the given element.
      TYPE(dbcsr_heap_type), INTENT(INOUT)               :: heap
      INTEGER, INTENT(IN)                                :: first
      INTEGER, INTENT(OUT)                               :: new_pos

      INTEGER                                            :: e, parent
      INTEGER(kind=valt)                                 :: my_value, parent_value
      LOGICAL                                            :: all_done

      DBCSR_ASSERT(0 < first .AND. first <= heap%n)

      e = first
      all_done = .FALSE.
      IF (e .GT. 1) THEN
         my_value = get_value(heap, e)
      END IF
      ! Check whether we are finished, i.e,. whether the element to
      ! bubble up is an orphan.
      new_pos = e
      DO WHILE (e .GT. 1 .AND. .NOT. all_done)
         ! Switches the parent and the current element if the current
         ! element's value is greater than the parent's value.
         parent = get_parent(e)
         parent_value = get_value(heap, parent)
         IF (my_value .LT. parent_value) THEN
            CALL dbcsr_heap_swap(heap, e, parent)
            e = parent
         ELSE
            all_done = .TRUE.
         END IF
      END DO
      new_pos = e
   END SUBROUTINE bubble_up

END MODULE dbcsr_min_heap
