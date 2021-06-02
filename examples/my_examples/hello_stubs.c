/* A simple Hello, World! example */
#include <stdio.h>
#include <caml/mlvalues.h>

CAMLprim value
caml_print_hello(value unit)
{
    printf("Hello OCaml!\n");
    return Val_unit;
}