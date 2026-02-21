writeonly uniform image2D colorimg15;

void write_indirect(vec3 color) {
    imageStore(colorimg15, ivec2(gl_FragCoord.xy), vec4(color, 1f));
}