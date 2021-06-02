# OCAMLOPT = /usr/local/bin/ocamlopt
APP = hello
CPROG = hello_stubs.c

all:
	# $(OCAMLOPT) -o $(APP).opt $(APP).ml $(CPROG)

	ocamlopt -o $(APP).opt $(APP).ml $(CPROG)
clean:
	rm *.o *.cmi *.cmx *.opt
