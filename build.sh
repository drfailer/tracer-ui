odin build src \
    -out:tracer_ui -debug \
    -collection:deps=../sgui/ \
    -extra-linker-flags:"-L$HOME/Programming/usr/lib -Wl,-rpath=$HOME/Programming/usr/lib" \
    -define:FONT="/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Regular.ttf"
