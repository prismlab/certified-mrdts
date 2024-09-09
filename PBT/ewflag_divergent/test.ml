
open Mrdt

let rec explore_configs_nr (cl:config list) (ns:int) (acc:config list) : config list =
  match cl with
  | [] -> acc
  | c1::cn ->
      if c1.ns = ns then explore_configs_nr cn ns (c1::acc)
      else if c1.ns > ns then explore_configs_nr cn ns acc
      else
        let new_c0 = 
          List.fold_left (fun acc i ->
            List.fold_left (fun inner_acc j ->
              let new_f = createBranch c1 i j in
              new_f::inner_acc
            ) acc (List.filter (fun r -> r <> i) (List.init (ns+1) (fun r -> r)))
          ) [] (RepSet.elements c1.r) in

        let new_cl = 
          List.fold_left (fun acc r1 ->
            let new_e = apply c1 r1 (gen_ts (), r1, Enable) in
            let new_d = apply c1 r1 (gen_ts (), r1, Disable) in
            new_e::new_d::acc
          ) [] (List.init ns (fun i -> i)) in

        let new_cl1 = 
          List.fold_left (fun acc i ->
            List.fold_left (fun inner_acc j ->
              let new_m = merge c1 i j in
              new_m::inner_acc
            ) acc (RepSet.elements (RepSet.remove i (c1.r)))
          ) [] (RepSet.elements c1.r) in
        
        explore_configs_nr (new_c0@(new_cl@(new_cl1@cn))) ns acc

let _ =
let start_time = Unix.gettimeofday () in
let ns = 6 in
let configs =
  if ns = 0 then [init_config]
  else explore_configs_nr [init_config] ns [] in
  let end_time = Unix.gettimeofday () in
  let total_time = end_time -. start_time in
  Printf.printf "\n\nLength of config list: %d" (List.length configs);
  Printf.printf "\nTotal execution time: %.6f seconds\n" total_time