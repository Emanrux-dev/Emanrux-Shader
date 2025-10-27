layout(triangles) in;

#include "/lib/settings.glsl"

#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD
layout(triangle_strip, max_vertices = 24) out;
#else
layout(triangle_strip, max_vertices = 3) out;
#endif

in vec4 vcolor[];
in float vVanillaAO[];

in vec4 vlmtexcoord[];
in vec4 vnormalMat[];

in vec4 vtexcoordam[]; // .st for add, .pq for mul
in vec4 vtexcoord[];

#ifdef MC_NORMAL_MAP
	in vec4 vtangent[];
	in vec3 vFlatNormals[];
#endif

flat in float vblockID[];

#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD
    in vec4 vgrassSideCheck[];
    in vec3 vcenterPosition[];
    out vec3 GrassNormals;
#endif

out vec4 color;
out float VanillaAO;

out vec4 lmtexcoord;
out vec4 normalMat;

out vec4 texcoordam; // .st for add, .pq for mul
out vec4 texcoord;

#ifdef MC_NORMAL_MAP
	out vec4 tangent;
	out vec3 FlatNormals;
#endif

flat out float blockID;


#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}

uniform int frameCounter;
uniform int hideGUI;
uniform float aspectRatio;
uniform float screenBrightness;

#include "/lib/TAA_jitter.glsl"
#include "/lib/res_params.glsl"
#include "/lib/bokeh.glsl"


uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform int framemod8;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform vec3 relativeEyePosition;
const float PI48 = 150.796447372*WAVY_SPEED;
float pi2wt = PI48*frameTimeCounter;

uniform sampler2D noisetex;

vec3 viewToWorld(vec3 viewPosition) {
    vec4 pos;
    pos.xyz = viewPosition;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}

vec2 calcWave(in vec3 pos) {

    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec2 ret = (sin(pi2wt*vec2(0.0063,0.0015)*4. - pos.xz + pos.y*0.05)+0.1)*magnitude;

    return ret;
}

vec3 calcMovePlants(in vec3 pos) {
    vec2 move1 = calcWave(pos);
	float move1y = -length(move1);
   return vec3(move1.x,move1y,move1.y)*5.*GRASS_WAVY_STRENGTH;
}

vec3 calculateNormal(vec3 v0, vec3 v1, vec3 v2) {
    vec3 edge1 = v1 - v0;
    vec3 edge2 = v2 - v0;
    vec3 normal = cross(edge1, edge2);
    return normalize(vec3(normal.x, normal.y, normal.z));
}

void main() {

    vec2 TAA_offsets = offsets[framemod8];
    
    int i;

    for (i = 0; i < 3; i++)
	{
		vec4 vertex = gl_in[i].gl_Position;

        #if defined PLANET_CURVATURE && !defined HAND
            float curvature = length(vertex.xyz) / (16.0*8.0);
            vertex.y -= curvature*curvature * CURVATURE_AMOUNT;
        #endif

        #if !defined ENTITIES && !defined HAND
        vertex = toClipSpace3(mat3(gbufferModelView) * vec3(vertex) + gbufferModelView[3].xyz);
        #endif

        gl_Position = vertex;

        #ifdef TAA_UPSCALING
            gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
        #endif
        #ifdef TAA
            // #ifdef HAND
                // turn off jitter when camera moves.
                // this is to hide the jitter when the same happens for TAA blend factor and the jitter becomes visible during camera movement
                // gl_Position.xy += (offsets[framemod8] * gl_Position.w*texelSize) * detectCameraMovement();
            // #else	
                gl_Position.xy += TAA_offsets * gl_Position.w*texelSize;
            // #endif
        #endif


        #if DOF_QUALITY == 5
            vec2 jitter = clamp(jitter_offsets[frameCounter % 64], -1.0, 1.0);
            jitter = rotate(radians(float(frameCounter))) * jitter;
            jitter.y *= aspectRatio;
            jitter.x *= DOF_ANAMORPHIC_RATIO;

            #if MANUAL_FOCUS == -2
            float focusMul = 0;
            #elif MANUAL_FOCUS == -1
            float focusMul = gl_Position.z - mix(pow(512.0, screenBrightness), 512.0 * screenBrightness, 0.25);
            #else
            float focusMul = gl_Position.z - MANUAL_FOCUS;
            #endif

            vec2 totalOffset = (jitter * JITTER_STRENGTH) * focusMul * 1e-2;
            gl_Position.xy += hideGUI >= 1 ? totalOffset : vec2(0);
        #endif

        color = vcolor[i];
        VanillaAO = vVanillaAO[i];
        lmtexcoord = vlmtexcoord[i];
        normalMat = vnormalMat[i];
        texcoordam = vtexcoordam[i];
        texcoord = vtexcoord[i];

        #ifdef MC_NORMAL_MAP
        tangent = vtangent[i];
        FlatNormals = vFlatNormals[i];
        #endif
        blockID = vblockID[i];

        #ifdef COLORWHEEL
            clrwl_setVertexOut(i);
        #endif

		EmitVertex();
	}
	EndPrimitive();

    #if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD

        int j;

        vec3 vertex = (gl_in[0].gl_Position+gl_in[1].gl_Position+gl_in[2].gl_Position).xyz/3.0;

        float vertexDist = length(vertex);

        #ifdef PLANET_CURVATURE
            float curvature = vertexDist / (16.0*8.0);
            vertex.y -= curvature*curvature * CURVATURE_AMOUNT;
        #endif

        #ifdef MC_NORMAL_MAP
            vec3 normals = viewToWorld(vFlatNormals[1]);
        #else
            const vec3 normals = vec3(0.0, 1.0, 0.0);
        #endif

        #if REPLACE_SHORT_GRASS == 2
            if (vblockID[1] == 85 && normals.y > 0.9 && vertexDist < GRASS_RANGE && vgrassSideCheck[0].x > 1.5)
        #else
            if (vblockID[1] == 85 && normals.y > 0.9 && vertexDist < GRASS_RANGE)
        #endif
        {
            #if GRASS_QUALITY == 2
                int triangle_count = 7;
                float heightMult = 1.1;
                if(vertexDist > 2.5) {triangle_count = 5; heightMult = 1.5;}
                if(vertexDist > 5.5) {triangle_count = 3; heightMult = 2.25;}
                if(vertexDist > 15.0) {triangle_count = 1; heightMult = 5.0;}
            #elif GRASS_QUALITY == 1
                int triangle_count = 5;
                float heightMult = 1.5;
                if(vertexDist > 7.5) {triangle_count = 3; heightMult = 2.25;}
                if(vertexDist > 15.0) {triangle_count = 1; heightMult = 5.0;}
            #else
                int triangle_count = 3;
                float heightMult = 2.25;
                if(vertexDist > 10.0) {triangle_count = 1; heightMult = 5.0;}
            #endif


            float eastHeightMult = pow(clamp(abs(vgrassSideCheck[0].x) * abs(vertex.x-(vcenterPosition[0].x-0.5)), 0.0, 1.0), 2.0);
            float westHeightMult = pow(clamp(abs(vgrassSideCheck[0].y) * abs(vertex.x-(vcenterPosition[0].x+0.5)), 0.0, 1.0), 2.0);
            float southHeightMult = pow(clamp(abs(vgrassSideCheck[0].z) * abs(vertex.z-(vcenterPosition[0].z-0.5)), 0.0, 1.0), 2.0);
            float northHeightMult = pow(clamp(abs(vgrassSideCheck[0].w) * abs(vertex.z-(vcenterPosition[0].z+0.5)), 0.0, 1.0), 2.0);

            eastHeightMult *= normalize(vgrassSideCheck[0].x);
            westHeightMult *= normalize(vgrassSideCheck[0].y);
            southHeightMult *= normalize(vgrassSideCheck[0].z);
            northHeightMult *= normalize(vgrassSideCheck[0].w);

            float totalHeightMult = 0.5*clamp(eastHeightMult + westHeightMult + southHeightMult + northHeightMult, -1.0*BASE_GRASS_HEIGHT*BASE_GRASS_HEIGHT, 1.0*SHORT_GRASS_HEIGHT) + 1.0*BASE_GRASS_HEIGHT;
            heightMult *= totalHeightMult;

            if(abs(vgrassSideCheck[0].x) > 1.5) { 
                eastHeightMult = 0.0;
                westHeightMult = 0.0;
                southHeightMult = 0.0;
                northHeightMult = 0.0;
            }

            vec2 edgeBlend = eastHeightMult*vec2(-0.17,0.0) + westHeightMult*vec2(0.17,0.0) + southHeightMult*vec2(0.0,-0.17) + northHeightMult*vec2(0.0,0.17);


            vec3 offsetPos = vertex+vec3(0.0, 1.0, 0.0)+relativeEyePosition;
            float playerDist = smoothstep(0.5, 0.05, length(offsetPos.xz)) * smoothstep(1.0, 0.2, abs(offsetPos.y));
            vec2 dir2 = normalize(vertex.xz+relativeEyePosition.xz);

            vec2 Wvertex = vertex.xz+cameraPosition.xz;

            vec2 randomDir = 2.0*(texture2D(noisetex, fract(GRASS_NOISE1_SCALE*Wvertex)).xy+texture2D(noisetex, fract(GRASS_NOISE2_SCALE*Wvertex.yx)).xy)-1.0;
            // vertex.xz -= 0.05*randomDir;


            vec3 dir = normalize(vertex);
            vec3 originalVertex = vertex;

            vec3 worldUp = vec3(0.0, 1.0, 0.0);

            vec3 right = GRASS_BASE_THICKNESS*normalize(cross(worldUp, dir));

            worldUp *= heightMult;

            originalVertex -= right*0.0625*GRASS_BASE_THICKNESS;

            vec3 verticies[21];
            float grassHeights[21];
            vec3 GrassNormal[7];

            for (j = 0; j < triangle_count; j++) {

                float jMod = j%2;
                
                vec3 heightOffset = 0.5*vec3(0.0, j-jMod, 0.0)*heightMult;


                vec3 worldOffset0 = heightOffset;
                vec3 worldOffset1 = worldUp + heightOffset;
                vec3 worldOffset2 = right + heightOffset;

                if(jMod == 1) {
                    worldOffset0 = right + heightOffset;
                    right *= GRASS_THICKNESS_FALLOFF;
                    worldOffset2 = right + worldUp + heightOffset;
                }

                if(j == triangle_count-1) worldOffset1 = 0.5*right + worldUp + heightOffset;

                vec3 worldOffsets[3] = vec3[](
                    worldOffset0,
                    worldOffset1,
                    worldOffset2
                );

                grassHeights[3*j] = 0.125 * worldOffset0.y;
                grassHeights[3*j+1] = 0.125 * worldOffset1.y;
                grassHeights[3*j+2] = 0.125 * worldOffset2.y;


                vec2 totalRandBend = GRASS_RANDOMNESS*randomDir + edgeBlend;

                for (i = 0; i < 3; i++)
                {
                    vec3 worldOffset = worldOffsets[i];
                    vertex = originalVertex;

                    float grassCurvature = smoothstep(0.0, 1.0, grassHeights[3*j+i]);

                    vertex.xz += 0.7*playerDist*vec2(dir2)*grassCurvature;

                    vertex.xz += grassCurvature*totalRandBend;

                    vertex += 1.6*calcMovePlants(vertex + cameraPosition)*grassCurvature*grassCurvature;

                    verticies[3*j+i] = vertex + 0.125 * worldOffset;
                }

                GrassNormal[j] = calculateNormal(verticies[3*j], verticies[3*j+1], verticies[3*j+2]);
            
            }

            for (j = 0; j < triangle_count; j++) {

                for (i = 0; i < 3; i++)
                {

                    gl_Position = toClipSpace3(mat3(gbufferModelView) * (verticies[3*j+i]) + gbufferModelView[3].xyz);

                    #ifdef TAA_UPSCALING
                        gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
                    #endif
                    #ifdef TAA
                        // #ifdef HAND
                            // turn off jitter when camera moves.
                            // this is to hide the jitter when the same happens for TAA blend factor and the jitter becomes visible during camera movement
                            // gl_Position.xy += (offsets[framemod8] * gl_Position.w*texelSize) * detectCameraMovement();
                        // #else	
                            gl_Position.xy += TAA_offsets * gl_Position.w*texelSize;
                        // #endif
                    #endif


                    #if DOF_QUALITY == 5
                        vec2 jitter = clamp(jitter_offsets[frameCounter % 64], -1.0, 1.0);
                        jitter = rotate(radians(float(frameCounter))) * jitter;
                        jitter.y *= aspectRatio;
                        jitter.x *= DOF_ANAMORPHIC_RATIO;

                        #if MANUAL_FOCUS == -2
                        float focusMul = 0;
                        #elif MANUAL_FOCUS == -1
                        float focusMul = gl_Position.z - mix(pow(512.0, screenBrightness), 512.0 * screenBrightness, 0.25);
                        #else
                        float focusMul = gl_Position.z - MANUAL_FOCUS;
                        #endif

                        vec2 totalOffset = (jitter * JITTER_STRENGTH) * focusMul * 1e-2;
                        gl_Position.xy += hideGUI >= 1 ? totalOffset : vec2(0);
                    #endif

                    float heightfade = smoothstep(-0.35, 1.0, grassHeights[3*j+i]);

                    // vec3 podzolColor = mix(vec3(0.15, 0.26, 0.01), vec3(168, 158, 91)/255., heightfade);

                    color = vcolor[i]*heightfade;

                    // if (vcolor[i].rgb == vec3(1.0)) color.rgb = podzolColor;
                    VanillaAO = vVanillaAO[i];
                    lmtexcoord = vlmtexcoord[i];
                    normalMat.xyz = vnormalMat[i].xyz;
                    normalMat.a = 0.4;

                    texcoordam = vtexcoordam[i];
                    texcoord = vtexcoord[i];

                    #ifdef MC_NORMAL_MAP
                        tangent = vtangent[i];
                        // FlatNormals = vFlatNormals[i];
                    
                        FlatNormals = GrassNormal[j];

                        heightfade = smoothstep(0.1, grassHeights[triangle_count], grassHeights[3*j+i]);
                        GrassNormals = normalize(mix(GrassNormal[0], GrassNormal[triangle_count-1], vec3(heightfade)));
                    #endif

                    blockID = -15.0;

                    EmitVertex();
                }
                EndPrimitive();
            }
        }
    #endif
}