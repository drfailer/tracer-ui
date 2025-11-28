odin build src -extra-linker-flags:"-L$HOME/Programming/usr/lib -Wl,-rpath=$HOME/Programming/usr/lib" -out:tracer_ui -debug -collection:deps=../sgui/
