#version 120
#define M_PI 3.14159265358979

const float FIELD_OF_VIEW = 60.0;
const float FOCAL_DIST = 1.0 / tan(M_PI * FIELD_OF_VIEW / 360.0);

const float MaximumRaySteps = 80.;
const float MinimumDistance = 0.0002;
const float Scale = 2.;
const float Iterations = 15;
const float Bailout = 5.;
const float Power = 2.;
const vec3 Offset = vec3(.15,.15,.15);

const vec3 BackgroundColor = vec3(0., 0., 0.1);

// Lighting constants
const vec3 lightPosition = vec3(0.,0.,10.);
const vec3 ambientColor = vec3(0.2,0.2,0.2);
const vec3 diffuseColor = vec3(.5,.5,.2);
const vec3 specColor = vec3(.3,.3,.3);
const float shininess = 64.;

uniform vec2 u_resolution;
uniform vec3 u_camera_position;
uniform mat4 u_view_matrix;

float de_sphere(vec3 p, float r){
	return abs(length(p)-r);
}

float de_sphereplane(vec3 p, float r){
	p.xy = mod((p.xy),1.0)-vec2(2.*r); // instance on xy-plane
	return length(p)-r;             // sphere DE*/
}

float de_recursive_thetrahedron(vec3 z){
    int n = 0;
    while (n < Iterations) {
       if(z.x+z.y<0) z.xy = -z.yx; // fold 1
       if(z.x+z.z<0) z.xz = -z.zx; // fold 2
       if(z.y+z.z<0) z.zy = -z.yz; // fold 3
       z = z*Scale - Offset*(Scale-1.0);
       n++;
    }
    return (length(z) ) * pow(Scale, -float(n));
}

float distanceEstimator(vec3 p){
	return de_sphereplane(p,0.2);
}

vec3 calculate_lighting(vec3 from, vec3 pos){
	// Blinn-Phong shading. See: https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model
	vec3 xDir = vec3(1.,0.,0.);
	vec3 yDir = vec3(0.,1.,0.);
	vec3 zDir = vec3(0.,0.,-1.);
	vec3 fractal_normal = normalize(vec3(distanceEstimator(pos+xDir) - distanceEstimator(pos-xDir),
					distanceEstimator(pos+yDir) - distanceEstimator(pos-yDir),
					distanceEstimator(pos+zDir) - distanceEstimator(pos-zDir)));

	vec3 lightDirection = normalize(lightPosition - pos);
	float lightDistance = pow(length(lightDirection),2.);

	float lambertian =  max (dot(lightDirection,fractal_normal),0.);
	vec3 viewDir = normalize (from - pos);
	vec3 halfDir =  normalize(lightDirection + viewDir);
	float specAngle = max(dot(halfDir, fractal_normal),0.);
	float specular = pow(specAngle,shininess);

	vec3 color = ambientColor + diffuseColor * lambertian + specColor * specular;
	return color;
}

vec3 ray_march(vec4 from, vec4 direction) {
	float distance = 0.0;
	float totalDistance = 0.0;
	float steps;
	for (steps=0.; steps < MaximumRaySteps; steps++) {
		vec4 pos = from + totalDistance * direction;


		distance = distanceEstimator(pos.xyz);
		totalDistance += distance;
		if (distance < MinimumDistance) break;
	}
	return vec3(distance, steps, totalDistance);
}

vec4 scene(inout vec4 origin, inout vec4 ray){
	vec3 marched = ray_march(origin, ray);
	float distance = marched.x;
	float steps = marched.y;
	float totalDistance = marched.z;

	vec3 color =  vec3(0.0);
	if (distance < MinimumDistance){
		color += calculate_lighting(origin.xyz, ray.xyz);
	}
	else {
		color += BackgroundColor;
	}
	return vec4(color, totalDistance);
}


void main(void)
{
	vec4 color = vec4(0.0);

	mat4 mat = u_view_matrix;

	// map screen coordiante to [-1..1] and correct aspect ratio
    vec2 uv = gl_FragCoord.xy / u_resolution;
	uv = uv * 2. - 1.;
	uv *= u_resolution / u_resolution.x;

	// convert screen coordinate to 3d ray
	vec4 ray = normalize(vec4(uv.x, uv.y, -FOCAL_DIST, 0.0));
	ray = mat * ray;

	// Camera Position
	vec4 p = mat[3];

	color += scene(p, ray);
	gl_FragColor = color;


}
