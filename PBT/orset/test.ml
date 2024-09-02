open OUnit2
open Mrdt

let test_config =
  let c = apply init_config 1 (gen_ts (), 1, Add 1) in
  let c1 = merge c 0 1 in
  let c2 = apply c1 2 (gen_ts (), 2, Add 2) in
  let c3 = apply c2 1 (gen_ts (), 1, Rem 2) in
  let c4 = apply c3 2 (gen_ts (), 2, Rem 1) in
  let c5 = merge c4 0 2 in
  let c6 = merge c5 0 1 in
  let c7 = merge c6 2 1 in
  (*let c8 = apply c7 2 (gen_ts (), 2, Rem 2) in*)
  c7

let sanity_check (c:config) = 
  assert (VerSet.equal c.g.vertices (vertices_from_edges c.g.edges))

let tests = "Test suite for MRDT" >::: [
  "sanity_check" >:: (fun _ -> sanity_check test_config);
  "print_dag" >:: (fun _ -> print_dag test_config);
  "print_lin" >:: (fun _ -> print_linearization (List.rev (test_config.l(test_config.h(0)))));
  "print_res" >:: (fun _ -> Printf.printf "\nLin result = ";
                            print_st (apply_events (List.rev (test_config.l(test_config.h(0)))));
                            Printf.printf "\nState = ";
                            print_st (test_config.n (test_config.h 0)));
  "test_lin" >:: (fun _ -> assert (eq (apply_events (List.rev (test_config.l(test_config.h(0))))) (test_config.n (test_config.h 0))));
]

let _ = run_test_tt_main tests
