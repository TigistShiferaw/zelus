(**************************************************************************)
(*                                                                        *)
(*  Author : Timothy Bourke                                               *)
(*  Organization : Synchronics, INRIA                                     *)
(*                                                                        *)
(**************************************************************************)

(* instantiate a numeric solver *)
module Load = Loadsolvers
let () = Zlsolve.check_for_solver Sys.argv
module Runtime = (val Zlsolve.instantiate () : Zlsolve.ZELUS_SOLVER)

let _ = GMain.init () (* initialize lablgtk2 *)

let start_playing = ref true

let destroy () = GMain.Main.quit ()

let () = Zlsolve.add_custom_arg
  ("-pause", Arg.Clear start_playing,
   " Start the simulator in paused mode.")

class step_task model_size model =
object (self)

  val mutable ss =
    Runtime.main' model_size model

  val mutable last_wall_clk = Unix.gettimeofday ()
  val mutable timer_id = None
  val mutable step_count = 0

  method private inc_step_count () = step_count <- step_count + 1
  method private reset_step_count () = step_count <- 0
  method private too_many_steps = step_count > 1000

  method private clear_timer () =
    match timer_id with
      None -> ()
    | Some id -> (GMain.Timeout.remove id;
                  timer_id <- None)

  method single_step () =
    let result, delta, ss' = Runtime.step ss in
    ss <- ss';
    Runtime.is_done ss

  method trigger_step () =
    self#clear_timer ();
    self#inc_step_count ();
    let result, delta, ss' = Runtime.step ss in
    ss <- ss';
    if Runtime.is_done ss then true
    else if delta <= 0.0 && not self#too_many_steps then self#trigger_step ()
    else
      let wall_clk = Unix.gettimeofday () in
      let delta' = delta -. (wall_clk -. last_wall_clk) in
      (* NB: cut losses at each continuous step: *)
      last_wall_clk <- wall_clk;
      if self#too_many_steps then begin
         prerr_string "Zlsrungtk: too fast!\n";
         flush stderr;
         self#reset_step_count ();
         (* Give GTK a chance to process other events *)
         timer_id <- Some (GMain.Timeout.add 10 self#trigger_step);
         true
        end
      else if delta' <= 0.0 then self#trigger_step ()
      else (
        (* NB: accumulate losses across steps: *)
        (* wall_clk_last := wall_clk; *)
        self#reset_step_count ();
        timer_id <- Some (GMain.Timeout.add
                           (int_of_float (delta' *. 1000.0)) self#trigger_step);
        true)

  method start () =
    last_wall_clk <- Unix.gettimeofday ();
    ignore (self#trigger_step ())

  method stop () = self#clear_timer ()
end

let go model_size model =
  let w = GWindow.window
    ~title:"Simulator"
    ~width:250
    ~height:70
    ~resizable:false
    () in

  let outer_box = GPack.vbox ~packing:w#add () in

  let top_box = GPack.button_box
    `HORIZONTAL
    ~packing:outer_box#pack
    ~child_width: 48
    ~child_height: 48
    ~layout:`SPREAD
    ()
  in

  let b_play = GButton.button
    ~packing:top_box#pack
    ~stock:`MEDIA_PLAY
    ()
  in
  let b_pause = GButton.button
    ~packing:top_box#pack
    ~stock:`MEDIA_PAUSE
    ()
  in
  let b_single = GButton.button
    ~packing:top_box#pack
    ~stock:`MEDIA_NEXT
    ()
  in
  b_pause#misc#set_sensitive false;

  let stask = new step_task model_size model in

  let s_speed_adj = GData.adjustment
    ~lower:1.0
    ~upper:20.0
    ~value:3.0
    ~step_incr:0.2
    ()
  in
  let original_speedup = !Runtime.speedup in
  let change_speedup x =
    let v = s_speed_adj#value in
    Runtime.speedup := original_speedup
        *. (if v <= 3.0 then v /. 3.0 else (v -. 3.0) *. 4.0);
    ignore (stask#trigger_step ())
    in
  ignore (s_speed_adj#connect#value_changed change_speedup);

  let s_speed = GRange.scale
    `HORIZONTAL
    ~adjustment:s_speed_adj
    ~draw_value:false
    ~packing:outer_box#pack
    ()
  in
  ignore (s_speed); (* avoid compiler warning *)

  let step_react_fun () =
    try
      if Printexc.print stask#single_step () then begin
          b_single#misc#set_sensitive false;
          b_play#misc#set_sensitive false;
          b_pause#misc#set_sensitive false;
          ()
        end
    with _ -> (destroy ()) in

  let play_pushed () =
      b_single#misc#set_sensitive false;
      b_play#misc#set_sensitive false;
      b_pause#misc#set_sensitive true;
      stask#start ()
  in

  let pause_pushed () =
      b_single#misc#set_sensitive true;
      b_play#misc#set_sensitive true;
      b_pause#misc#set_sensitive false;
      stask#stop ()
  in

  ignore (b_play#connect#clicked ~callback:play_pushed);
  ignore (b_pause#connect#clicked ~callback:pause_pushed);
  ignore (b_single#connect#clicked ~callback:step_react_fun);

  if !start_playing then play_pushed ();

  ignore (w#connect#destroy ~callback:destroy);
  w#show ();
  GMain.Main.main ()
