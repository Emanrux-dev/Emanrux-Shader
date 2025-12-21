#include "/lib/settings.glsl"

#ifdef ENCHANT_GLINT
    #include "/lib/SSBOs.glsl"
#endif

in DATA {
    vec4 color;
    vec2 texcoord;
};

uniform sampler2D gtexture;

//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}


//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

/* RENDERTARGETS:2 */

void main() {

	vec4 Albedo = texture(gtexture, texcoord);

    #ifndef COLORWHEEL
	    Albedo.rgb = toLinear(Albedo.rgb * color.rgb);
    #else
        vec2 lmcoord;
        float ao;
        vec4 overlayColor;

        clrwl_computeFragment(Albedo, Albedo, lmcoord, ao, overlayColor);

        Albedo.rgb = mix(Albedo.rgb, overlayColor.rgb, overlayColor.a);

        Albedo.rgb = toLinear(Albedo.rgb);
    #endif

    #if defined BEACON_BEAM
	    gl_FragData[0] = vec4(Albedo.rgb*Albedo.rgb * 0.1 * 5.0 * Emissive_Brightness, Albedo.a*color.a);
    #endif

    #if defined LIGHTNING_AND_DRAGON_DEATH_BEAMS
        gl_FragData[0] = vec4(Albedo.rgb * pow(1.0-pow(1.0-color.a,2),2) * 5.0 * 0.1, color.a);
    #endif

    #if defined SPIDER_EYES || defined GLOWING 

        if(Albedo.a < 1.0/255.0 || dot(Albedo.rgb, vec3(0.33333)) < 1.0/255.0) { discard; return; }

        #ifdef DISABLE_VANILLA_EMISSIVES
            vec3 emissiveColor = vec3(0.0);
            Albedo.a = 0.0;
        #else
            vec3 emissiveColor = Albedo.rgb * Albedo.a * Emissive_Brightness;
        #endif
        
	    gl_FragData[0] = vec4(emissiveColor*0.1, 0.000001);
    #endif

    #ifdef ENCHANT_GLINT

        Albedo.rgb = clamp(Albedo.rgb ,0.0,1.0); // for safety

        #ifdef DISABLE_ENCHANT_GLINT
            vec3 GlintColor = vec3(0.0);
            Albedo.a = 0.0;
        #else
            vec3 GlintColor = Albedo.rgb * 0.65 * ENCHANT_GLINT_BRIGHTNESS * avgBrightnessSSBO * color.a;
        #endif

	    gl_FragData[0] = vec4(GlintColor*0.1, 0.000001);
    #endif
}