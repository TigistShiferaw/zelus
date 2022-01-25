#include <stdio.h>
#include <string.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include "hash_tbl.h"
//#include <lcm/lcm.h>
//#include "robot_store_t.h"
#include <time.h>

//#define MBOT_MOTOR_TRANSVERSE_CHANNEL "MBOT_MOTOR_TRANSVERSE"

// Sends motor commands to the robot
float a=5.0;
CAMLprim value 
robot_get_cpp(value var)
{
    //std::string key = String_val(var);
    //printf("Command: %s\n", (String_val(var)));
    printf("Robot get %s\n", String_val(var));
    a=get_value(String_val(var));
    //printf("%f", a);
    return caml_copy_double(a);
}
//CAMLparam1 (var);
//CAMLlocal1 (v_res);
//std::string key= String_val(var);
 //std::cout<< "Inside variable ! \n"<<key;
//v_res= Val_int(a);
//CAMLreturn (v_res);

CAMLprim value
move_robot_cpp(value speed){
	return Val_unit;
}


CAMLprim value
robot_store_c(value cmd,value mag){
	return Val_unit;
}

CAMLprim value
robot_str_cpp(value cmd,value mag){
	printf("Inside robot store");
	insert_to_table(String_val(cmd), Double_val(mag));
	return Val_unit;
}

CAMLprim value
control_robot_c(value t_speed, value a_speed){
	return Val_unit;
}