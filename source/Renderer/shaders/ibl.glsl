vec3 getDiffuseLight(vec3 n)
{
    return texture(u_LambertianEnvSampler, u_envRotation * n).rgb;
}

vec4 getSpecularSample(vec3 reflection, float lod)
{
    return textureLod(u_GGXEnvSampler, u_envRotation * reflection, lod);
}

vec4 getSheenSample(vec3 reflection, float lod)
{
    return textureLod(u_CharlieEnvSampler, u_envRotation * reflection, lod);
}

vec3 getIBLRadianceGGX(vec3 n, vec3 v, float roughness, vec3 F0)
{
    float NdotV = clampedDot(n, v);
    float lod = clamp(roughness * float(u_MipCount), 0.0, float(u_MipCount));
    vec3 reflection = normalize(reflect(-v, n));

    vec2 brdfSamplePoint = clamp(vec2(NdotV, roughness), vec2(0.0, 0.0), vec2(1.0, 1.0));
    vec2 f_ab = texture(u_GGXLUT, brdfSamplePoint).rg;
    vec4 specularSample = getSpecularSample(reflection, lod);

    vec3 specularLight = specularSample.rgb;

    // see https://bruop.github.io/ibl/#single_scattering_results at Single Scattering Results
    // Roughness dependent fresnel, from Fdez-Aguera
    vec3 Fr = max(vec3(1.0 - roughness), F0) - F0;
    vec3 k_S = F0 + Fr * pow(1.0 - NdotV, 5.0);
    vec3 FssEss = k_S * f_ab.x + f_ab.y;

    return specularLight * FssEss;
}

vec3 getTransmissionSample(vec2 fragCoord, float roughness)
{
    float framebufferLod = log2(float(u_TransmissionFramebufferSize.x)) * roughness;

    vec3 transmittedLight = textureLod(u_TransmissionFramebufferSampler, fragCoord.xy, framebufferLod).rgb;

    transmittedLight = sRGBToLinear(transmittedLight);

    return transmittedLight;
}


vec3 getIBLRadianceTransmission(vec3 n, vec3 v, vec2 fragCoord, float roughness, vec3 baseColor, vec3 f0, vec3 f90)
{

    // Sample GGX LUT.
    float NdotV = clampedDot(n, v);
    vec2 brdfSamplePoint = clamp(vec2(NdotV, roughness), vec2(0.0, 0.0), vec2(1.0, 1.0));
    vec2 brdf = texture(u_GGXLUT, brdfSamplePoint).rg;
    vec3 specularColor = f0 * brdf.x + f90 * brdf.y;

    vec3 transmittedLight = getTransmissionSample(fragCoord.xy, roughness);

    return (1.0-specularColor) * transmittedLight * baseColor;
}



vec3 getIBLRadianceLambertian(vec3 n, vec3 v, float roughness, vec3 diffuseColor, vec3 F0)
{
    float NdotV = clampedDot(n, v);
    vec2 brdfSamplePoint = clamp(vec2(NdotV, roughness), vec2(0.0, 0.0), vec2(1.0, 1.0));
    vec2 f_ab = texture(u_GGXLUT, brdfSamplePoint).rg;

    vec3 diffuseLight = getDiffuseLight(n);

    // see https://bruop.github.io/ibl/#single_scattering_results at Single Scattering Results
    // Roughness dependent fresnel, from Fdez-Aguera
    vec3 Fr = max(vec3(1.0 - roughness), F0) - F0;
    vec3 k_S = F0 + Fr * pow(1.0 - NdotV, 5.0);
    vec3 FssEss = k_S * f_ab.x + f_ab.y;

    // Multiple scattering, from Fdez-Aguera
    float Ems = (1.0 - (f_ab.x + f_ab.y));
    vec3 F_avg = F0 + (1.0 - F0) / 21.0;
    vec3 FmsEms = Ems * FssEss * F_avg / (1.0 - F_avg * Ems);
    vec3 k_D = diffuseColor * (1.0 - FssEss - FmsEms);

    return (FmsEms + k_D) * diffuseLight ;
}

vec3 getIBLRadianceCharlie(vec3 n, vec3 v, float sheenRoughness, vec3 sheenColor)
{
    float NdotV = clampedDot(n, v);
    float lod = clamp(sheenRoughness * float(u_MipCount), 0.0, float(u_MipCount));
    vec3 reflection = normalize(reflect(-v, n));

    vec2 brdfSamplePoint = clamp(vec2(NdotV, sheenRoughness), vec2(0.0, 0.0), vec2(1.0, 1.0));
    float brdf = texture(u_CharlieLUT, brdfSamplePoint).b;
    vec4 sheenSample = getSheenSample(reflection, lod);

    vec3 sheenLight = sheenSample.rgb;
    return sheenLight * sheenColor * brdf;
}
