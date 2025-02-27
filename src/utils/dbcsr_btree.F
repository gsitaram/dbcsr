!--------------------------------------------------------------------------------------------------!
! Copyright (C) by the DBCSR developers group - All rights reserved                                !
! This file is part of the DBCSR library.                                                          !
!                                                                                                  !
! For information on the license, see the LICENSE file.                                            !
! For further information please visit https://dbcsr.cp2k.org                                      !
! SPDX-License-Identifier: GPL-2.0+                                                                !
!--------------------------------------------------------------------------------------------------!

#:include 'dbcsr_btree.fypp'

MODULE dbcsr_btree
   !! B-tree
   IMPLICIT NONE
   PRIVATE

   !API
   PUBLIC :: btree_new, btree_add, btree_find, &
             btree_delete, btree_get_entries
   #:for nt in nametype
      PUBLIC :: btree_${nt}$
   #:endfor

   INTEGER, PARAMETER :: keyt = SELECTED_INT_KIND(10)
   INTEGER, PARAMETER :: valt = SELECTED_INT_KIND(5)
   INTEGER, PARAMETER :: sp = KIND(0.0)
   INTEGER, PARAMETER :: dp = KIND(0.0d0)

   #:for ts in type2setup
      $:ts
   #:endfor

   INTERFACE btree_new
      #:for nt in nametype
         MODULE PROCEDURE btree_new_${nt}$
      #:endfor
   END INTERFACE

   INTERFACE btree_add
      #:for nt in nametype
         MODULE PROCEDURE btree_add_${nt}$
      #:endfor
   END INTERFACE

   INTERFACE btree_find
      #:for nt in nametype
         MODULE PROCEDURE btree_find_${nt}$
      #:endfor
   END INTERFACE

   INTERFACE btree_delete
      #:for nt in nametype
         MODULE PROCEDURE btree_delete_${nt}$
      #:endfor
   END INTERFACE

   INTERFACE btree_get_entries
      #:for nt in nametype
         MODULE PROCEDURE btree_get_entries_${nt}$
      #:endfor
   END INTERFACE

   #:for nametype, nametype1, nametype2, type1, type2, defaultFormatType1, defaultFormatType2, accessorType2 in inst_params
      TYPE btree_node_${nametype}$
         INTEGER :: id = -1
         INTEGER :: filled = -1
         ${type1}$, DIMENSION(:), POINTER :: keys => NULL()
         ${type2}$, DIMENSION(:), POINTER :: values => NULL()
         TYPE(btree_node_p_${nametype}$), DIMENSION(:), POINTER :: subtrees => NULL()
         TYPE(btree_node_${nametype}$), POINTER :: parent => NULL()
      END TYPE btree_node_${nametype}$

      TYPE btree_node_p_${nametype}$
         TYPE(btree_node_${nametype}$), POINTER :: node => NULL()
      END TYPE btree_node_p_${nametype}$

      TYPE btree_node_structure_${nametype}$
         INTEGER :: min_fill = -1, max_fill = -1
         INTEGER :: n = -1
         INTEGER :: lastid = -1
         INTEGER :: refcount = -1
         TYPE(btree_node_${nametype}$), POINTER :: root => NULL()
      END TYPE btree_node_structure_${nametype}$

      TYPE btree_${nametype}$
         TYPE(btree_node_structure_${nametype}$) :: b = btree_node_structure_${nametype}$ ()
      END TYPE btree_${nametype}$
   #:endfor

CONTAINS

   #:for nametype, nametype1, nametype2, type1, type2, defaultFormatType1, defaultFormatType2, accessorType2 in inst_params
      SUBROUTINE btree_new_${nametype}$ (tree, order)
         TYPE(btree_${nametype}$), INTENT(OUT) :: tree
         INTEGER, INTENT(IN), OPTIONAL :: order
         INTEGER :: maxs, mins
         !
         IF (PRESENT(order)) THEN
            maxs = order - 1
         ELSE
            maxs = 15
         END IF
         mins = ISHFT(maxs, -1)
         IF (mins*2 .GT. maxs) maxs = 2*maxs
         IF (mins .LT. 1) mins = 1
         IF (maxs .LT. 3) maxs = 3
         tree%b%min_fill = mins
         tree%b%max_fill = maxs
         tree%b%refcount = 1
         tree%b%n = 0
         NULLIFY (tree%b%root)
         tree%b%lastid = 0
      END SUBROUTINE btree_new_${nametype}$

      FUNCTION btree_get_entries_${nametype}$ (tree) RESULT(num_entries)
         TYPE(btree_${nametype}$), INTENT(INOUT) :: tree
         INTEGER :: num_entries
         num_entries = tree%b%n
      END FUNCTION btree_get_entries_${nametype}$

      ! node is a non-leaf node
      SUBROUTINE btree_adopt_subtrees_${nametype}$ (node)
         TYPE(btree_node_${nametype}$), POINTER :: node
         INTEGER :: i
         !
         ! Assume that node is not a leaf!
         DO i = 1, node%filled + 1
            !IF (ASSOCIATED (node%subtrees(i)%node)) THEN
            !IF (.NOT. ASSOCIATED (node%subtrees(i)%node%parent,&
            ! node)) THEN
            node%subtrees(i)%node%parent => node
            !ENDIF
            !ENDIF
         END DO
      END SUBROUTINE btree_adopt_subtrees_${nametype}$

      SUBROUTINE btree_delete_${nametype}$ (tree, keys, values)
         TYPE(btree_${nametype}$), INTENT(INOUT) :: tree
         ${type1}$, DIMENSION(:), INTENT(OUT), OPTIONAL :: keys
         ${type2}$, DIMENSION(:), INTENT(OUT), OPTIONAL :: values
         INTEGER :: pos
         !
         IF (ASSOCIATED(tree%b%root)) THEN
            pos = 0
            IF (PRESENT(keys) .AND. PRESENT(values)) THEN
               pos = 1
               CALL btree_delete_node_${nametype}$ (tree%b%root, pos, keys, values)
            ELSE
               CALL btree_delete_node_${nametype}$ (tree%b%root)
            END IF
         END IF
         NULLIFY (tree%b%root)
      END SUBROUTINE btree_delete_${nametype}$

      RECURSIVE SUBROUTINE btree_delete_node_${nametype}$ (node, pos, keys, values)
         TYPE(btree_node_${nametype}$), POINTER :: node
         INTEGER, INTENT(INOUT), OPTIONAL :: pos
         ${type1}$, DIMENSION(:), INTENT(INOUT), OPTIONAL :: keys
         ${type2}$, DIMENSION(:), INTENT(INOUT), OPTIONAL :: values
         !
         INTEGER :: i
         !
         IF (node%filled .GT. 0 .AND. ASSOCIATED(node%subtrees(1)%node)) THEN
            DO i = 1, node%filled + 1
               IF (PRESENT(pos)) THEN
                  CALL btree_delete_node_${nametype}$ (node%subtrees(i)%node, pos, keys, values)
               ELSE
                  CALL btree_delete_node_${nametype}$ (node%subtrees(i)%node)
               END IF
               IF (PRESENT(pos) .AND. i .LE. node%filled) THEN
                  keys(pos) = node%keys(i)
                  values(pos) = node%values(i)
                  pos = pos + 1
               END IF
            END DO
         ELSEIF (PRESENT(pos) .AND. node%filled .GT. 0) THEN
            keys(pos:pos + node%filled - 1) = node%keys(1:node%filled)
            values(pos:pos + node%filled - 1) = node%values(1:node%filled)
            pos = pos + node%filled
         END IF
         CALL btree_free_node_${nametype}$ (node)
      END SUBROUTINE btree_delete_node_${nametype}$

      ! Find the key
      ! IF node still has space, insert & update the node
      ! else
      ! 1. select median
      ! 2. split keys into two nodes (one is new)
      ! 3. insert separation key put into parent, and repeat upwards

      SUBROUTINE btree_add_${nametype}$ (tree, key, value, exists, existing_value, replace)
         TYPE(btree_${nametype}$), INTENT(INOUT) :: tree
         ${type1}$, INTENT(IN) :: key
         ${type2}$, INTENT(IN) :: value
         LOGICAL, INTENT(OUT), OPTIONAL :: exists
         ${type2}$, INTENT(OUT), OPTIONAL :: existing_value
         LOGICAL, INTENT(IN), OPTIONAL :: replace
         !
         TYPE(btree_node_${nametype}$), POINTER :: node
         INTEGER :: ge_pos, position
         !
         IF (PRESENT(exists)) THEN
            CALL btree_find_full_${nametype}$ (tree, key, node, position, ge_pos, short=.TRUE.)
            IF (position .GT. 0) THEN
               exists = .TRUE.
               existing_value = node%values(position)
               IF (PRESENT(replace)) THEN
                  IF (replace) THEN
                     node%values(position) = value
                  END IF
               END IF
               RETURN
            ELSE
               exists = .FALSE.
            END IF
         ELSE
            CALL btree_find_leaf_${nametype}$ (tree, key, node, ge_pos)
         END IF
         CALL btree_add_into_${nametype}$ (tree, node, key, value, before=ge_pos)
         IF (PRESENT(exists)) existing_value = value
         tree%b%n = tree%b%n + 1
      END SUBROUTINE btree_add_${nametype}$

      RECURSIVE SUBROUTINE btree_add_into_${nametype}$ (tree, node, key, value, before, subtree)
         TYPE(btree_${nametype}$), INTENT(INOUT) :: tree
         TYPE(btree_node_${nametype}$), POINTER :: node
         ${type1}$, INTENT(IN) :: key
         ${type2}$, INTENT(IN) :: value
         INTEGER, INTENT(IN), OPTIONAL :: before
         TYPE(btree_node_${nametype}$), POINTER, OPTIONAL :: subtree
         !
         TYPE(btree_node_${nametype}$), POINTER :: new_node
         ${type1}$ :: upgrade_key
         INTEGER :: ge_pos, split_pos
         ${type2}$ :: upgrade_value
         LOGICAL :: leaf
         !
         ! Root is special
         IF (.NOT. ASSOCIATED(node)) THEN
            CALL btree_new_root_${nametype}$ (tree, key, value)
            IF (PRESENT(subtree)) THEN
               tree%b%root%subtrees(2)%node => subtree
               subtree%parent => tree%b%root
            END IF
            RETURN
         END IF
         ! Where the insertion takes place.
         IF (PRESENT(before)) THEN
            ge_pos = before
         ELSE
            CALL btree_node_find_gt_pos_${nametype}$ (node%keys, key, ge_pos, node%filled)
         END IF
         ! Addition is easy if the node has enough space.
         leaf = .NOT. ASSOCIATED(node%subtrees(1)%node)
         IF (node%filled .LT. tree%b%max_fill) THEN
            IF (PRESENT(subtree)) THEN
               CALL btree_simple_insertion_${nametype}$ (node, key, value, ge_pos, subtree)
            ELSE
               CALL btree_simple_insertion_${nametype}$ (node, key, value, ge_pos)
            END IF
            RETURN
         ELSE
            split_pos = ISHFT(tree%b%max_fill + 1, -1)
            ! I assert that split_pos <= SIZE(node%keys)
            CALL btree_new_node_${nametype}$ (tree, new_node)
            ! The key to be added falls in the left node
            node%filled = split_pos - 1
            IF (ge_pos .LE. split_pos) THEN
               IF (ge_pos .EQ. split_pos) THEN
                  upgrade_key = key
                  upgrade_value = value
               ELSE
                  upgrade_key = node%keys(split_pos - 1)
                  upgrade_value = node%values(split_pos - 1)
               END IF
               IF (PRESENT(subtree)) THEN
                  CALL btree_left_insertion_${nametype}$ (tree, node, new_node, key, value, &
                                                          ge_pos, split_pos, subtree)
                  !CALL btree_adopt_subtrees_${nametype}$ (new_node)
               ELSE
                  CALL btree_left_insertion_${nametype}$ (tree, node, new_node, key, value, &
                                                          ge_pos, split_pos)
               END IF
               !
            ELSE
               upgrade_key = node%keys(split_pos)
               upgrade_value = node%values(split_pos)
               IF (PRESENT(subtree)) THEN
                  CALL btree_right_insertion_${nametype}$ (tree, node, new_node, key, value, &
                                                           ge_pos, split_pos, subtree)
                  !CALL btree_adopt_subtrees_${nametype}$ (new_node)
               ELSE
                  CALL btree_right_insertion_${nametype}$ (tree, node, new_node, key, value, &
                                                           ge_pos, split_pos)
               END IF
               !
            END IF
            !
            new_node%parent => node%parent
            !
            IF (.NOT. leaf) THEN
               CALL btree_adopt_subtrees_${nametype}$ (new_node)
            END IF
            !
            CALL btree_add_into_${nametype}$ (tree, node%parent, upgrade_key, upgrade_value, &
                                              subtree=new_node)
            !
         END IF
      END SUBROUTINE btree_add_into_${nametype}$

      SUBROUTINE btree_simple_insertion_${nametype}$ (node, key, value, before, subtree)
         TYPE(btree_node_${nametype}$), INTENT(INOUT) :: node
         ${type1}$, INTENT(IN) :: key
         ${type2}$, INTENT(IN) :: value
         INTEGER, INTENT(IN) :: before
         TYPE(btree_node_${nametype}$), POINTER, OPTIONAL :: subtree
         !
         ! Shift keys
         node%keys(before + 1:node%filled + 1) = node%keys(before:node%filled)
         node%keys(before) = key
         ! Shift values
         node%values(before + 1:node%filled + 1) = node%values(before:node%filled)
         node%values(before) = value
         ! Shift subtree pointers, but only if node is not a leaf ; assume
         ! leaf <=> present(subtree)
         IF (PRESENT(subtree)) THEN
            node%subtrees(before + 2:node%filled + 2) = &
               node%subtrees(before + 1:node%filled + 1)
            node%subtrees(before + 1)%node => subtree
         END IF
         node%filled = node%filled + 1
      END SUBROUTINE btree_simple_insertion_${nametype}$

      SUBROUTINE btree_left_insertion_${nametype}$ (tree, node, new_node, key, value, before, split_pos, subtree)
         TYPE(btree_${nametype}$), INTENT(IN) :: tree
         TYPE(btree_node_${nametype}$), INTENT(INOUT) :: node, new_node
         ${type1}$, INTENT(IN) :: key
         ${type2}$, INTENT(IN) :: value
         INTEGER, INTENT(IN) :: before, split_pos
         TYPE(btree_node_${nametype}$), POINTER, OPTIONAL :: subtree
         !
         new_node%filled = (tree%b%max_fill) - (split_pos - 1)
         new_node%keys(1:new_node%filled) = &
            node%keys(split_pos:tree%b%max_fill)
         new_node%values(1:new_node%filled) = &
            node%values(split_pos:tree%b%max_fill)
         !IF (ASSOCIATED (node%subtrees(1)%node)) THEN
         IF (PRESENT(subtree)) THEN
            IF (before .EQ. split_pos) THEN
               new_node%subtrees(2:new_node%filled + 1) = &
                  node%subtrees(split_pos + 1:tree%b%max_fill + 1)
               new_node%subtrees(1)%node => subtree
            ELSE
               new_node%subtrees(1:new_node%filled + 1) = &
                  node%subtrees(split_pos:tree%b%max_fill + 1)
            END IF
         END IF
         ! Fill node%{keys,values}(1:node%filled), where node%filled
         ! is split_pos-1, but do insert the new value at ge_pos. The
         ! key/value at split_pos is to be inserted into the
         ! parent.
         ! The new tree is added to the right of the new insertion.
         node%keys(before + 1:node%filled) = node%keys(before:node%filled - 1)
         node%keys(before) = key
         node%values(before + 1:node%filled) = node%values(before:node%filled - 1)
         node%values(before) = value
         IF (PRESENT(subtree)) THEN
            node%subtrees(before + 2:node%filled + 1) = &
               node%subtrees(before + 1:node%filled)
            node%subtrees(before + 1)%node => subtree
         ELSE
            NULLIFY (node%subtrees(before + 1)%node)
         END IF
      END SUBROUTINE btree_left_insertion_${nametype}$

      SUBROUTINE btree_right_insertion_${nametype}$ (tree, node, new_node, key, value, before, split_pos, subtree)
         TYPE(btree_${nametype}$), INTENT(IN) :: tree
         TYPE(btree_node_${nametype}$), INTENT(INOUT) :: node, new_node
         ${type1}$, INTENT(IN) :: key
         ${type2}$, INTENT(IN) :: value
         INTEGER, INTENT(IN) :: before, split_pos
         TYPE(btree_node_${nametype}$), POINTER, OPTIONAL :: subtree
         !
         new_node%filled = (tree%b%max_fill + 1) - split_pos
         new_node%keys(1:before - split_pos - 1) = &
            node%keys(split_pos + 1:before - 1)
         new_node%keys(before - split_pos) = key
         new_node%keys(before - split_pos + 1:new_node%filled) = &
            node%keys(before:tree%b%max_fill)
         new_node%values(1:before - split_pos - 1) = &
            node%values(split_pos + 1:before - 1)
         new_node%values(before - split_pos) = value
         new_node%values(before - split_pos + 1:new_node%filled) = &
            node%values(before:tree%b%max_fill)
         IF (PRESENT(subtree)) THEN
            new_node%subtrees(1:before - split_pos) = &
               node%subtrees(split_pos + 1:before)
            new_node%subtrees(before - split_pos + 1)%node => subtree
            new_node%subtrees(before - split_pos + 2:new_node%filled + 1) = &
               node%subtrees(before + 1:tree%b%max_fill + 1)
         END IF
      END SUBROUTINE btree_right_insertion_${nametype}$

      SUBROUTINE btree_new_root_${nametype}$ (tree, key, value)
         TYPE(btree_${nametype}$), INTENT(INOUT) :: tree
         ${type1}$, INTENT(IN) :: key
         ${type2}$, INTENT(IN) :: value
         TYPE(btree_node_${nametype}$), POINTER :: old_root, new_root
         !
         CALL btree_new_node_${nametype}$ (tree, new_root)
         new_root%filled = 1
         new_root%keys(1) = key
         new_root%values(1) = value
         IF (ASSOCIATED(tree%b%root)) THEN
            old_root => tree%b%root
            old_root%parent => new_root
            new_root%subtrees(1)%node => old_root
            old_root%parent => new_root
         END IF
         tree%b%root => new_root
      END SUBROUTINE btree_new_root_${nametype}$

      SUBROUTINE btree_new_node_${nametype}$ (tree, node)
         TYPE(btree_${nametype}$), INTENT(INOUT) :: tree
         TYPE(btree_node_${nametype}$), POINTER :: node
         INTEGER :: i
         !
         ALLOCATE (node)
         ALLOCATE (node%keys(tree%b%max_fill))
         ALLOCATE (node%values(tree%b%max_fill))
         ALLOCATE (node%subtrees(tree%b%max_fill + 1))
         DO i = 1, tree%b%max_fill + 1
            NULLIFY (node%subtrees(i)%node)
         END DO
         node%filled = 0
         NULLIFY (node%parent)
         tree%b%lastid = tree%b%lastid + 1
         node%id = tree%b%lastid
      END SUBROUTINE btree_new_node_${nametype}$

      SUBROUTINE btree_free_node_${nametype}$ (node)
         TYPE(btree_node_${nametype}$), POINTER :: node
         !
         DEALLOCATE (node%keys)
         DEALLOCATE (node%values)
         DEALLOCATE (node%subtrees)
         DEALLOCATE (node)
      END SUBROUTINE btree_free_node_${nametype}$

      SUBROUTINE btree_find_${nametype}$ (tree, key, value, exists)
         TYPE(btree_${nametype}$), INTENT(IN) :: tree
         ${type1}$, INTENT(IN) :: key
         ${type2}$, INTENT(OUT) :: value
         LOGICAL, INTENT(OUT), OPTIONAL :: exists
         !
         TYPE(btree_node_${nametype}$), POINTER :: node
         INTEGER :: position
         !
         CALL btree_find_full_${nametype}$ (tree, key, node, position, short=.TRUE.)
         IF (PRESENT(exists)) THEN
            exists = position .GT. 0
         END IF
         IF (position .GT. 0) THEN
            value = node%values(position)
         END IF
      END SUBROUTINE btree_find_${nametype}$

      SUBROUTINE btree_node_find_ge_pos_${nametype}$ (keys, key, position, filled)
         ${type1}$, DIMENSION(:) :: keys
         ${type1}$, INTENT(IN) :: key
         INTEGER, INTENT(OUT) :: position
         INTEGER, INTENT(IN) :: filled
         INTEGER :: left, right
         !
         IF (keys(1) .GE. key) THEN
            position = 1
            RETURN
         END IF
         IF (keys(filled) .LT. key) THEN
            position = filled + 1
            RETURN
         END IF
         left = 2
         right = filled
         position = MAX(ISHFT(left + right, -1), left)
         DO WHILE (left .LE. right)
            IF (keys(position) .GE. key .AND. keys(position - 1) .LT. key) THEN
               RETURN
            END IF
            IF (keys(position) .GE. key) right = MIN(position, right - 1)
            IF (keys(position) .LT. key) left = MAX(position, left + 1)
            position = MAX(ISHFT(left + right, -1), left)
         END DO
      END SUBROUTINE btree_node_find_ge_pos_${nametype}$

      SUBROUTINE btree_node_find_gt_pos_${nametype}$ (keys, key, position, filled)
         ${type1}$, DIMENSION(:) :: keys
         ${type1}$, INTENT(IN) :: key
         INTEGER, INTENT(OUT) :: position
         INTEGER, INTENT(IN) :: filled
         INTEGER :: left, right
         !
         IF (keys(1) .GT. key) THEN
            position = 1
            RETURN
         END IF
         IF (keys(filled) .LE. key) THEN
            position = filled + 1
            RETURN
         END IF
         left = 2
         right = filled
         position = MAX(ISHFT(left + right, -1), left)
         DO WHILE (left .LE. right)
            IF (keys(position) .GT. key .AND. keys(position - 1) .LE. key) THEN
               RETURN
            END IF
            IF (keys(position) .GT. key) right = MIN(position, right - 1)
            IF (keys(position) .LE. key) left = MAX(position, left + 1)
            position = MAX(ISHFT(left + right, -1), left)
         END DO
      END SUBROUTINE btree_node_find_gt_pos_${nametype}$

      SUBROUTINE btree_node_find_gte_pos_${nametype}$ (keys, key, position, filled, first)
         ${type1}$, DIMENSION(:) :: keys
         ${type1}$, INTENT(IN) :: key
         INTEGER, INTENT(OUT) :: position
         INTEGER, INTENT(IN) :: filled
         INTEGER, INTENT(IN), OPTIONAL :: first
         INTEGER :: left, right, one
         !
         one = 1
         IF (PRESENT(FIRST)) one = first
         IF (one .LE. filled) THEN
            IF (keys(one) .GT. key) THEN
               position = one
               RETURN
            END IF
         END IF
         IF (keys(filled) .LE. key) THEN
            position = filled + 1
            RETURN
         END IF
         left = one + 1
         right = filled
         position = MAX(ISHFT(left + right, -1), left)
         DO WHILE (left .LE. right)
            IF (keys(position) .GT. key .AND. keys(position - 1) .LE. key) THEN
               RETURN
            END IF
            IF (keys(position) .GT. key) right = MIN(position, right - 1)
            IF (keys(position) .LE. key) left = MAX(position, left + 1)
            position = MAX(ISHFT(left + right, -1), left)
         END DO
      END SUBROUTINE btree_node_find_gte_pos_${nametype}$

      ! node is unassociated and position=0 if not found
      ! Precondition: The key is tree or its subtree.

      SUBROUTINE btree_find_full_${nametype}$ (tree, key, node, position, ge_position, short)
         TYPE(btree_${nametype}$), INTENT(IN) :: tree
         ${type1}$, INTENT(IN) :: key
         TYPE(btree_node_${nametype}$), POINTER :: node
         INTEGER, INTENT(OUT) :: position
         INTEGER, INTENT(OUT), OPTIONAL :: ge_position
         LOGICAL, INTENT(IN), OPTIONAL :: short
         INTEGER :: gti ! Used mark searches
         LOGICAL :: stop_short
         !
         stop_short = .FALSE.
         IF (PRESENT(short)) stop_short = short
         NULLIFY (node)
         position = 0
         IF (PRESENT(ge_position)) ge_position = 0
         !IF (tree%b%n .EQ. 0) RETURN
         IF (.NOT. ASSOCIATED(tree%b%root)) RETURN
         gti = 1
         ! Try to find the key in the given node. If it's found, then
         ! return the node.
         node => tree%b%root
         descent: DO WHILE (.TRUE.)
            ! Try to find the first element equal to or greater than the
            ! one we're searching for.
            CALL btree_node_find_ge_pos_${nametype}$ (node%keys, key, position, node%filled)
            ! One of three things is now true about position: it's now
            ! greater than the number of keys (if all keys are smaller), or
            ! it points to the key that is equal to or greater than the one
            ! we are searching for. If it is found and we are just
            ! searching for one equal element (i.e., user search), we can
            ! return.
            IF (stop_short .AND. position .LE. node%filled) THEN
               IF (node%keys(position) .EQ. key) THEN
                  IF (PRESENT(ge_position)) ge_position = position
                  RETURN
               END IF
            END IF
            ! If the key is not found, then either return the GE position
            ! if we're in a leaf (case 2 here), otherwise descend into the
            ! subtrees.
            !CALL btree_node_find_gt_pos_${nametype}$ (node%keys, key, gti, node%filled, position)
            CALL btree_node_find_gte_pos_${nametype}$ (node%keys, key, gti, node%filled, position)
            IF (ASSOCIATED(node%subtrees(1)%node)) THEN
               node => node%subtrees(gti)%node
            ELSE
               IF (PRESENT(ge_position)) ge_position = gti
               position = 0
               RETURN
            END IF
         END DO descent
      END SUBROUTINE btree_find_full_${nametype}$

      ! node is unassociated and position=0 if not found
      ! Precondition: The key is tree or its subtree.

      SUBROUTINE btree_find_leaf_${nametype}$ (tree, key, node, gti)
         TYPE(btree_${nametype}$), INTENT(IN) :: tree
         ${type1}$, INTENT(IN) :: key
         TYPE(btree_node_${nametype}$), POINTER :: node
         INTEGER, INTENT(OUT) :: gti
         !
         NULLIFY (node)
         !IF (tree%b%n .EQ. 0) RETURN
         IF (.NOT. ASSOCIATED(tree%b%root)) RETURN
         gti = 1
         ! Try to find the key in the given node. If it's found, then
         ! return the node.
         node => tree%b%root
         descent: DO WHILE (.TRUE.)
            ! Try to find the first element equal to or greater than the
            ! one we're searching for.
            !CALL btree_node_find_ge_pos_${nametype}$ (node%keys, key, position, node%filled)
            ! One of three things is now true about position: it's now
            ! greater than the number of keys (if all keys are smaller), or
            ! it points to the key that is equal to or greater than the one
            ! we are searching for. If it is found and we are just
            ! searching for one equal element (i.e., user search), we can
            ! return.
            !
            ! If the key is not found, then either return the GE position
            ! if we're in a leaf (case 2 here), otherwise descend into the
            ! subtrees.
            CALL btree_node_find_gt_pos_${nametype}$ (node%keys, key, gti, node%filled)
            !CALL btree_node_find_gt2_pos_${nametype}$ (node%keys, key, i, node%filled)
            !IF (i .NE. gti) WRITE(*,*)'XXXX difference',i,gti
            IF (ASSOCIATED(node%subtrees(1)%node)) THEN
               node => node%subtrees(gti)%node
            ELSE
               RETURN
            END IF
         END DO descent
      END SUBROUTINE btree_find_leaf_${nametype}$
   #:endfor

END MODULE dbcsr_btree
