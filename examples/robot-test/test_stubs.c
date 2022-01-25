#include <stdio.h>
#include <caml/mlvalues.h>
//#include <lcm/lcm.h>
//#include "mbot_motor_command_t.h"
#include <time.h>

//#define MBOT_MOTOR_COMMAND_CHANNEL "MBOT_MOTOR_COMMAND"

// Sends motor commands to the robot
CAMLprim value
move_robot_cpp(value speed){
//	lcm_t * lcm = lcm_create("udpm://239.255.76.67:7667?ttl=1");
  //   mbot_motor_command_t cmd;
    //cmd.utime = (unsigned long)time(NULL);
    // Need to divide by 100 and convert to float since motor speeds come in as hundredths of units (and as integer arguments)
    //cmd.trans_v = Int_val(speed)/100.0;
	//cmd.angular_v = 0.;
    //mbot_motor_command_t_publish(lcm, MBOT_MOTOR_COMMAND_CHANNEL, &cmd);
	//lcm_destroy(lcm);
	printf ("%s", "Hi there from c");
	int trans_v= Int_val(speed);
	printf("%d\n", trans_v);
    return Val_unit;

}
CAMLprim value
control_robot_c(value t_speed, value a_speed){
	return Val_unit;
}
CAMLprim value
robot_store_c(value command, value magnitude){
	return Val_unit;
}

CAMLprim value
robot_str_cpp(value command, value magnitude){
	return Val_unit;
}
CAMLprim value
robot_get_cpp(value command){
	return Val_unit;
}
CAMLprim value
inp_c(value channel){
        printf ("%s", String_val(channel));
	return Val_unit;
}

CAMLprim value
oup_c(value channel){
        printf ("%s", String_val(channel));
	return Val_unit;
	}