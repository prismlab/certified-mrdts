module Polymorphic_gmap

module S = FStar.Set //Set_extended

let concrete_st_a = int

let concrete_st_b = S.set nat

let init_st_a = 0

let init_st_b = S.empty

let symmetric_a a b = ()

let symmetric_b a b = ()

let transitive_a a b c = ()

let transitive_b a b c = ()

let eq_is_equiv_a a b = ()

let eq_is_equiv_b a b = ()

type app_op_a : eqtype =
  |Inc

type app_op_b : eqtype =
  |Add : nat -> app_op_b

let do_a s o = s + 1

let do_b s o = let _,(_,Add e) = o in S.add e s

let get_ele (o:op_t{is_beta_op o}) =
  let (Set _ (Beta_op (Add e))) = snd (snd o) in e

let rc_a o1 o2 = Either

let rc_b o1 o2 = Either

let merge_a l a b = a + b - l

let merge_b l a b = S.union l (S.union a b)

/////////////////////////////////////////////////////////////////////////////

let lem_eq (a b:concrete_st)
  : Lemma (requires (forall k. S.equal (sel a (Beta_t k)) (sel b (Beta_t k)) /\ (sel a (Alpha_t k) == sel b (Alpha_t k))) /\
                    (forall k. M.contains a k = M.contains b k))
          (ensures eq a b)
          [SMTPat (eq a b)] = ()

let lem_eq_b (a b:concrete_st_b)
  : Lemma (requires S.equal a b)
          (ensures eq_b a b)
          [SMTPat (eq_b a b)] = ()

#set-options "--ifuel 3"
let rc_non_comm o1 o2 = ()
let no_rc_chain o1 o2 o3 = ()
let cond_comm_base s o1 o2 o3 = ()
let cond_comm_ind s o1 o2 o3 o l = ()

////////////////////////////////////////////////////////////////////////////

let merge_comm_a l a b = ()
let merge_comm_b l a b = 
  ()//assert (S.equal (S.union l (S.union a b)) (S.union l (S.union b a))); ()

let merge_idem_a s = ()
let merge_idem_b s = 
  ()//assert (S.equal (S.union s (S.union s s)) s); ()

////////////////////////////////////////////////////////////////////////////

let rc_ind_right_a l a b o1 o2 o2' = ()
let rc_ind_right_b l a b o1 o2 o2' = ()
let rc_ind_right_ne l a b o1 o2 o2' = ()

let rc_ind_left_a l a b o1 o2 o1' = ()
let rc_ind_left_b l a b o1 o2 o1' = ()
let rc_ind_left_ne l a b o1 o2 o1' = ()

let rc_ind_lca_a l o1 o2 o = ()
let rc_ind_lca_b l o1 o2 o = ()
let rc_ind_lca_ne l o1 o2 o = ()

let rc_base o1 o2 t = ()

let rc_inter_base_right_a l a b c o1 o2 ob ol = ()
let rc_inter_base_right_b l a b c o1 o2 ob ol = ()
let rc_inter_base_right_ne l a b c o1 o2 ob ol = ()

let rc_inter_base_left_a l a b c o1 o2 ob ol = ()
let rc_inter_base_left_b l a b c o1 o2 ob ol = ()
let rc_inter_base_left_ne l a b c o1 o2 ob ol = ()

let rc_inter_right_a l a b c o1 o2 ob ol o = ()
let rc_inter_right_b l a b c o1 o2 ob ol o = ()
let rc_inter_right_ne l a b c o1 o2 ob ol o = ()

let rc_inter_left_a l a b c o1 o2 ob ol o = ()
let rc_inter_left_b l a b c o1 o2 ob ol o = ()
let rc_inter_left_ne l a b c o1 o2 ob ol o = ()

let rc_inter_lca_a l a b c o1 o2 ol oi = ()
let rc_inter_lca_b l a b c o1 o2 ol oi = ()
let rc_inter_lca_ne l a b c o1 o2 ol oi = ()

let one_op_ind_right_a l a b o2 o2' = ()

let one_op_ind_right_b l a b o2 o2' =
  ()//assert (S.equal (S.union l (S.union a (do_b (do_b b o2') o2))) (do_b (S.union l (S.union a (do_b b o2'))) o2)); ()

let one_op_ind_right_ne l a b o2 o2' = ()

let one_op_ind_left_a l a b o1 o1' = ()
let one_op_ind_left_b l a b o1 o1' = 
  () //assert (S.equal (S.union l (S.union (do_b (do_b a o1') o1) b)) (do_b (S.union l (S.union (do_b a o1') b)) o1)); ()
  
let one_op_ind_left_ne l a b o1 o1' = ()

let one_op_ind_lca_a l o2 o = ()
let one_op_ind_lca_b l o2 o = 
  () //assert (S.equal (S.union (do_b l o) (S.union (do_b l o) (do_b (do_b l o) o2))) (do_b (do_b l o) o2)); ()
  
let one_op_ind_lca_ne l o2 o = ()

let one_op_base_a o2 = ()
let one_op_base_b o2 = 
  () //assert (S.equal (S.union init_st_b (S.union init_st_b (do_b init_st_b o2))) (do_b init_st_b o2)); ()

let one_op_inter_base_right_a l a b c o2 ob ol = ()
let one_op_inter_base_right_b l a b c o2 ob ol = ()
let one_op_inter_base_right_ne l a b c o2 ob ol = ()

let one_op_inter_base_left_a l a b c o2 ob ol = ()
let one_op_inter_base_left_b l a b c o2 ob ol = ()
let one_op_inter_base_left_ne l a b c o2 ob ol = ()

let one_op_inter_right_a l a b c o2 ob ol o = ()
let one_op_inter_right_b l a b c o2 ob ol o = ()
let one_op_inter_right_ne l a b c o2 ob ol o = ()

let one_op_inter_left_a l a b c o2 ob ol o = ()
let one_op_inter_left_b l a b c o2 ob ol o = ()
let one_op_inter_left_ne l a b c o2 ob ol o = ()

let one_op_inter_lca_a l a b c o2 ol oi o = ()
let one_op_inter_lca_b l a b c o2 ol oi o = ()
let one_op_inter_lca_ne l a b c o2 ol oi o = ()

let zero_op_inter_base_right_a l a b c ob ol = ()
let zero_op_inter_base_right_b l a b c ob ol = ()
let zero_op_inter_base_right_ne l a b c ob ol = ()

let zero_op_inter_base_left_a l a b c ob ol = ()
let zero_op_inter_base_left_b l a b c ob ol = ()
let zero_op_inter_base_left_ne l a b c ob ol = ()

let zero_op_inter_right_a l a b c ob ol o = ()
let zero_op_inter_right_b l a b c ob ol o = ()
let zero_op_inter_right_ne l a b c ob ol o = ()

let zero_op_inter_left_a l a b c ob ol o = ()
let zero_op_inter_left_b l a b c ob ol o = ()
let zero_op_inter_left_ne l a b c ob ol o = ()

let zero_op_inter_lca_v1_a l a b c ol = ()
let zero_op_inter_lca_v1_b l a b c ol = ()

let zero_op_inter_lca_v2_a l a b c ol oi = ()
let zero_op_inter_lca_v2_b l a b c ol oi = ()
let zero_op_inter_lca_v2_ne l a b c ol oi = ()

let comm_ind_right_a l a b o1 o2 o2' = ()
let comm_ind_right_b l a b o1 o2 o2' = 
  ()//assert (S.equal (S.union l (S.union (do_b a o1) (do_b (do_b b o2') o2))) (do_b (do_b (merge_b l a (do_b b o2')) o2) o1)); ()

#set-options "--z3rlimit 100 --ifuel 3"
let comm_ind_right_ne l a b o1 o2 o2' = ()

let comm_ind_left_a l a b o1 o2 o1' = ()
let comm_ind_left_b l a b o1 o2 o1' = 
  () //assert (S.equal (S.union l (S.union (do_b (do_b a o1') o1) (do_b b o2))) (do_b (do_b (merge_b l (do_b a o1') b) o2) o1)); ()
  
let comm_ind_left_ne l a b o1 o2 o1' = ()

let comm_ind_lca_a l ol o1 o2 = ()
let comm_ind_lca_b l ol o1 o2 = 
  () //assert (S.equal (S.union (do_b l ol) (S.union (do_b (do_b l ol) o1) (do_b (do_b l ol) o2))) (do_b (do_b (do_b l ol) o2) o1)); ()
  
let comm_ind_lca_ne l ol o1 o2 = ()

let comm_base o1 o2 t = ()

let comm_inter_base_right_a l a b c o1 o2 ob ol = ()
let comm_inter_base_right_b l a b c o1 o2 ob ol = ()
let comm_inter_base_right_ne l a b c o1 o2 ob ol = ()

let comm_inter_base_left_a l a b c o1 o2 ob ol = ()
let comm_inter_base_left_b l a b c o1 o2 ob ol = ()
let comm_inter_base_left_ne l a b c o1 o2 ob ol = ()

let comm_inter_right_a l a b c o1 o2 ob ol o = ()
let comm_inter_right_b l a b c o1 o2 ob ol o = ()
let comm_inter_right_ne l a b c o1 o2 ob ol o = ()

let comm_inter_left_a l a b c o1 o2 ob ol o = ()
let comm_inter_left_b l a b c o1 o2 ob ol o = ()
let comm_inter_left_ne l a b c o1 o2 ob ol o = ()

let comm_inter_lca_a l a b c o1 o2 ol = ()
let comm_inter_lca_b l a b c o1 o2 ol = ()
let comm_inter_lca_ne l a b c o1 o2 ol = ()
