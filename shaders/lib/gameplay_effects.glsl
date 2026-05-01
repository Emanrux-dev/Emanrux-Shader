#ifdef IS_IRIS
    uniform float currentPlayerHealth;
    uniform float maxPlayerHealth;
    uniform float oneHeart;
    uniform float threeHeart;

    uniform float CriticalDamageTaken;
    uniform float MinorDamageTaken;
#else
    uniform bool isDead;
#endif

uniform float exitWater;
uniform float enterWater;
uniform float exitLava;
uniform int isEyeInWater;
uniform float is_burning;
uniform float is_soul_burning;





void applyGameplayEffects(inout vec3 color, in vec2 texcoord, float noise){
   
    #ifdef IS_IRIS
        bool isDead = currentPlayerHealth * maxPlayerHealth <= 0.0 && currentPlayerHealth > -1;
    #else
        float oneHeart = 0.0;
        float threeHeart = 0.0;
    #endif

    float distortmask = 0.0;
    float vignette = sqrt(clamp(dot(texcoord*2.0 - 1.0, texcoord*2.0 - 1.0) * 0.5, 0.0, 1.0));

    #if defined LOW_HEALTH_EFFECT || defined DAMAGE_TAKEN_EFFECT   
        float heartBeat = (pow(sin(frameTimeCounter * 15)*0.5+0.5,2.0)*0.2 + 0.1) ;
        float damageDistortion = vignette * noise * heartBeat * threeHeart;
        damageDistortion = mix(damageDistortion, vignette * (0.5 + noise), CriticalDamageTaken) * MOTION_AMOUNT;
        distortmask = isDead ? vignette * (0.7 + noise*0.3) : damageDistortion;
    #endif

    #if defined WATER_ON_CAMERA_EFFECT
        if(exitWater > 0.0){
            vec3 scale = vec3(1.0,1.0,0.0);
            bool eyeInWater = isEyeInWater == 1;
            scale.xy = (eyeInWater ? vec2(0.3) : vec2(0.5, 0.25 + (exitWater*exitWater)*0.25 ) ) * vec2(aspectRatio,1.0);
            scale.z = eyeInWater ? 0.0 : exitWater;

            float waterDrops = texture(noisetex, (texcoord - vec2(0.0, scale.z)) * scale.xy).r ;
            if(eyeInWater) waterDrops = 0.0;
            if(isEyeInWater == 0 && exitWater > 0.0) waterDrops = sqrt(min(max(waterDrops - (1.0-sqrt(exitWater))*0.7,0.0) * (1.0 + exitWater),1.0)) * 0.3;

            distortmask = max(distortmask, waterDrops);
        }
        if(enterWater > 0.0){
            vec2 zoomTC = 0.5 + (texcoord - 0.5) * (1.0 - (1.0-sqrt(1.0-enterWater)) );
            float waterSplash = texture(noisetex, zoomTC * vec2(aspectRatio,1.0)).r * (1.0-enterWater);
            distortmask = max(distortmask, waterSplash);
        }
    #endif

    #if defined ON_FIRE_DISTORT_EFFECT
        if(exitLava > 0.0){
            vec2 zoomin = 0.5 + (texcoord - 0.5) * (1.0-pow(1.0-clamp(-texcoord.y*0.5+0.75,0.0,1.0),1.0)) * (1.0-pow(1.0-exitLava,2.0));
            vec2 UV = zoomin;
            float flameDistort = texture(noisetex, UV * vec2(aspectRatio,1.0) - vec2(0.0,frameTimeCounter*0.3)).b * clamp(-texcoord.y*0.3+0.3,0.0,1.0) * ON_FIRE_DISTORT_EFFECT_STRENGTH * exitLava;
            distortmask = max(distortmask, flameDistort);
        }
    #endif

    vec2 zoomUV = 0.5 + (texcoord - 0.5) * (1.0 - distortmask);
    
    #ifndef PIXELATED
        vec3 distortedColor = texture(colortex7, zoomUV).rgb;
    #else
        vec2 fragCoord = zoomUV*view_res;
        vec3 distortedColor = texelFetch(colortex7, ivec2(fragCoord)-ivec2(mod(fragCoord, PIXELIZATION_STRENGTH)), 0).rgb;
    #endif

    #if defined WATER_ON_CAMERA_EFFECT || defined ON_FIRE_DISTORT_EFFECT
        if(exitWater > 0.01 || exitLava > 0.01) {
            color = distortedColor;
        }
    #endif

    #if defined LOW_HEALTH_EFFECT || defined DAMAGE_TAKEN_EFFECT   
        vec3 distortedColorLuma = vec3(1.0, 0.0, 0.0) * dot(distortedColor, vec3(0.21, 0.72, 0.07));
    
        #ifdef LOW_HEALTH_EFFECT
            float colorLuma = dot(color, vec3(0.21, 0.72, 0.07));
            vec3 LumaRedEdges = mix(vec3(colorLuma), vec3(1.0, 0.3, 0.3) * distortedColorLuma.r, vignette);
            color = mix(color, LumaRedEdges, mix(vignette * threeHeart, oneHeart, oneHeart));
        #endif

        #ifdef DAMAGE_TAKEN_EFFECT
            color = mix(color, distortedColorLuma, vignette * sqrt(min(MinorDamageTaken,1.0)));
            color = mix(color, distortedColorLuma, sqrt(CriticalDamageTaken));
        #endif

        if(isDead) color = distortedColorLuma * 0.35;
    #endif

    #if defined ON_FIRE_DISTORT_EFFECT

    #endif

    #if defined FIRE_COLOR_CORRECTION
        bool nearSoulBlock = (nearSoulBlockSSBO == 1);

        if (nearSoulBlock) {
            if (is_burning > 0.0) {
                float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
                vec3 soulColor = vec3(0.08, 0.38, 1.0) * luma * 1.8;
                float strength = clamp((0.22 + vignette * 0.32), 0.0, 0.6);
                color = mix(color, soulColor, strength);

                vec2 fuv = texcoord;
                float ftime = frameTimeCounter * 3.0;

                vec2 q = fuv;
                q.x += sin(q.y * 5.0 + ftime) * 0.05;

                float fn1 = texture(noisetex, q * vec2(1.0, 0.5) + vec2(ftime * 0.1, -ftime * 0.8)).b;
                float fn2 = texture(noisetex, q * vec2(2.0, 1.0) + vec2(-ftime * 0.2, -ftime * 1.5)).b;

                float fireShape = (fn1 + fn2) * 0.5;
                fireShape = pow(fireShape, 1.5) * 2.0;

                float fireMask = smoothstep(0.1, 0.7, 1.0 - fuv.y);
                fireMask *= smoothstep(-0.2, 0.5, vignette + 0.3);

                float fireIntensity = smoothstep(0.4, 0.8, fireShape * fireMask);

                vec3 flameColors = mix(vec3(0.0, 0.3, 0.8), vec3(0.1, 0.8, 1.0), smoothstep(0.0, 0.7, fireShape));
                flameColors = mix(flameColors, vec3(0.8, 1.0, 1.0), smoothstep(0.6, 1.0, fireIntensity));

                color = color + flameColors * fireIntensity * 1.8;
            }
            float particles = 0.0;
            vec2 pUV = texcoord * vec2(aspectRatio, 1.0);
            float time = frameTimeCounter;

            for(int i = 0; i < 3; i++) {
                vec2 p = pUV * (12.0 + float(i) * 6.0); 
                p.y += time * (1.0 + float(i) * 0.4);
                
                vec2 id = floor(p);
                vec2 local_p = fract(p) - 0.5;
                
                float rnd = fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453);
                
                if (rnd > 0.985) {
                    local_p.x += (fract(rnd * 34.2) - 0.5) * 0.4;
                    local_p.y += (fract(rnd * 89.3) - 0.5) * 0.4;
                    local_p.x += sin(time * 2.0 + id.y * 10.0 + id.x) * 0.15;
                    local_p.y += cos(time * 2.5 + id.x * 5.0) * 0.05;
                    
                    float radius = 0.11 + rnd * 0.05;
                    vec2 gv = local_p / radius;
                    
                    gv.x += sin(gv.y * 4.0 - time * 8.0) * 0.25 * smoothstep(0.1, -1.5, gv.y);
                    
                    float bY = gv.y;
                    float bX = gv.x / (0.45 + smoothstep(-1.5, 1.0, bY) * 0.7);
                    
                    float distBody = length(vec2(bX, bY));
                    float body = smoothstep(1.0, 0.2, distBody);
                    
                    float distEye1 = length(vec2(gv.x + 0.35, (gv.y - 0.4) * 0.6));
                    float distEye2 = length(vec2(gv.x - 0.35, (gv.y - 0.4) * 0.6));
                    float distMouth = length(vec2(gv.x, (gv.y + 0.1) * 0.4));
                    
                    float faces = smoothstep(0.15, 0.25, min(distEye1, distEye2));
                    faces *= smoothstep(0.15, 0.25, distMouth);
                    
                    float tailFade = smoothstep(-1.6, -0.2, bY);
                    
                    particles += (body * faces * tailFade) * (0.6 + 0.4 * rnd);
                }
            }

            float screenFade = smoothstep(0.35, 0.48, abs(texcoord.x - 0.5));
            vec3 soulCyan = vec3(0.1, 0.7, 1.0);
            color = color + soulCyan * clamp(particles, 0.0, 1.0) * screenFade * 1.8;
        }
        

    #endif
    #endif
}
