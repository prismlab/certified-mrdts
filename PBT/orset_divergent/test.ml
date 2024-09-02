open OUnit2
open Mrdt

let test_config =
  let c = apply init_config 2 (gen_ts (), 2, Add 'a') in
  let c1 = apply c 1 (gen_ts (), 1, Add 'a') in
  let c2 = merge c1 0 1 in
  let c3 = apply c2 1 (gen_ts (), 1, Rem 'a') in
  let c4 = merge c3 0 2 in
  let c5 = merge c4 0 1 in
  c5

let r = 0
let sanity_check (c:config) = 
  assert (VerSet.equal c.g.vertices (vertices_from_edges c.g.edges))

let tests = "Test suite for MRDT" >::: [
  "sanity_check" >:: (fun _ -> sanity_check test_config);
  "print_dag" >:: (fun _ -> print_dag test_config);
  "print_lin" >:: (fun _ -> print_linearization (List.rev (test_config.l(test_config.h(r)))));
  "print_res" >:: (fun _ -> Printf.printf "\nLin result = ";
                            print_st (apply_events (List.rev (test_config.l(test_config.h(r)))));
                            Printf.printf "\nState = ";
                            print_st (test_config.n (test_config.h r)));
  "test_lin1" >:: (fun _ -> assert (eq (apply_events (List.rev (test_config.l(test_config.h(0))))) (test_config.n (test_config.h 0))));
  "test_lin2" >:: (fun _ -> assert (eq (apply_events (List.rev (test_config.l(test_config.h(1))))) (test_config.n (test_config.h 1))));
  "test_lin3" >:: (fun _ -> assert (eq (apply_events (List.rev (test_config.l(test_config.h(2))))) (test_config.n (test_config.h 2))));
]

let _ = run_test_tt_main tests
