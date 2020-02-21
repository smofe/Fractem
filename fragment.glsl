#version 120
#define M_PI 3.14159265358979

// camera constants
const float FIELD_OF_VIEW = 60.0;
const float FOCAL_DIST = 1.0 / tan(M_PI * FIELD_OF_VIEW / 360.0);

// ray marching constants
const float MAXIMUM_RAY_STEPS = 130.;
const float MINIMUM_DISTANCE = 0.0002;



// Lighting constants
const vec3 BACKGROUND_COLOR = vec3(0., 0., 0.1);
const vec3 LIGHT_POSITION = vec3(0.,0.,10.);
const vec3 LIGHT_DIRECTION = vec3(-0.36,0.48,0.80);
const vec3 COLOR_AMBIENT = vec3(0.2,0.2,0.2);
const vec3 COLOR_DIFFUSE = vec3(.5,.5,.2);
const vec3 COLOR_SPECULAR = vec3(.5,.5,.5);
const float SHININESS = 64.;
const float AMBIENT_OCCLUSION_STRENGTH = 0.01;
const vec3 AMBIENT_OCCLUSION_COLOR_DELTA = vec3(0.8,0.8,0.8);

// uniforms
uniform vec2 u_resolution;
uniform vec3 u_camera_position;
uniform mat4 u_view_matrix;
uniform float u_timer; // [0,1]


/* Folding functions */
void sierpinskiFold(inout vec3 z) {
	z.xy -= min(z.x + z.y, 0.0);
	z.xz -= min(z.x + z.z, 0.0);
	z.yz -= min(z.y + z.z, 0.0);
}
void planeFold(inout vec3 z, vec3 n, float d) {
	z -= 2.0 * min(0.0, dot(z.xyz, n) - d) * n;
}
void absFold(inout vec3 z, vec3 c) {
	z = abs(z - c) + c;
}
void repeatFoldX(inout vec3 p, float m){
	p.x = abs(mod(p.x - m/2,m) - m/2);
}
void repeatFoldY(inout vec3 p, float m){
	p.y = abs(mod(p.y - m/2,m) - m/2);
}
void repeatFoldZ(inout vec3 p, float m){
	p.z = abs(mod(p.z - m/2,m) - m/2);
}
void mengerFold(inout vec3 z) {
	float a = min(z.x - z.y, 0.0);
	z.x -= a;
	z.y += a;
	a = min(z.x - z.z, 0.0);
	z.x -= a;
	z.z += a;
	a = min(z.y - z.z, 0.0);
	z.y -= a;
	z.z += a;
}
void sphereFold(inout vec3 z, float minR, float maxR) {
	float r2 = dot(z.xyz, z.xyz);
	z *= max(maxR / max(minR, r2), 1.0);
}
void boxFold(inout vec3 z, vec3 r) {
	z.xyz = clamp(z.xyz, -r, r) * 2.0 - z.xyz;
}
void rotX(inout vec3 z, float s, float c) {
	z.yz = vec2(c*z.y + s*z.z, c*z.z - s*z.y);
}
void rotY(inout vec3 z, float s, float c) {
	z.xz = vec2(c*z.x - s*z.z, c*z.z + s*z.x);
}
void rotZ(inout vec3 z, float s, float c) {
	z.xy = vec2(c*z.x + s*z.y, c*z.y - s*z.x);
}
void rotX(inout vec3 z, float a) {
	rotX(z, sin(a), cos(a));
}
void rotY(inout vec3 z, float a) {
	rotY(z, sin(a), cos(a));
}
void rotZ(inout vec3 z, float a) {
	rotZ(z, sin(a), cos(a));
}

/* Distance Estimators */

float de_sphere(vec3 p, float r){
	return abs(length(p)-r);
}


vec4 de_abstractspace(vec3 p){
	vec3 color = vec3(.5,.5,.5);

	for (float i=0.; i < 5.; i++){
		//rotX(p,9*u_timer);
		boxFold(p,vec3(.1,.3*u_timer,.2*u_timer));
		repeatFoldX(p,2.0 + 2.*u_timer);
		repeatFoldY(p,2.0);
		repeatFoldZ(p,2.0);
		rotY(p,2*u_timer);
		rotZ(p,1*u_timer);
		sphereFold(p,.3,.1+.2*u_timer);
	}
	color = normalize(p);
	return vec4(color, abs(length(p)-.005));
}

vec4 de_sphereplane(vec3 p, float r){
	p.xy = mod((p.xy),1.0)-vec2(2.*r); // instance on xy-plane
	vec3 color = normalize(vec3(u_timer - fract(length(p)),fract(p.y),fract(length(p)) * fract(p.x)));
	return vec4(color,length(p)-r*u_timer);             // sphere DE*/
}

vec4 de_recursive_thetrahedron(vec3 z){
	vec3 offset = vec3(.3,.3,.3);
	float scale = 2.;
	const float iterations = 15;
    int n = 0;

    while (n < iterations) {
		rotY(z,25);
		rotZ(z,65);
		sierpinskiFold(z);
       	z = z*scale - offset*(scale-1.0);
       	n++;
    }
	vec3 color = vec3(z.x,z.y,z.z) ;
    return vec4(color,(length(z) ) * pow(scale, -float(n)));
}


/* returns baseColor, distance*/
vec4 de_mandlebulb(vec3 pos) {
	vec3 z = pos*u_timer;
	float dr = 1.0;
	float r = 0.;
	float Bailout = 5. + 10. * u_timer;
	float Power = 2 + 2* u_timer;
	float Iterations = 15;
	vec3 color = vec3(0.0,0.0,1.0);

	for (int i = 0; i < Iterations ; i++) {
		r = length(z);
		if (r>Bailout) break;
		// convert to polar coordinates
		float theta = acos(z.z/r);
		if (abs(z.x) < 0.001) z.x = 0.01;
		if (abs(z.y) < 0.001) z.y = 0.01;
		float phi = atan(z.y,z.x);

		dr =  pow( r, Power-1.0)*Power*dr + 1.0;

		// scale and rotate the point
		float zr = pow( r,Power);
		theta = theta*Power;
		phi = phi*Power;

		// convert back to cartesian coordinates
		z = zr*vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z+=pos;
	}
	color = normalize(vec3(1. - fract(length(pos)* 50. * u_timer),fract(length(pos)* 20.),fract(length(pos)* 5.)));
	return vec4(color,0.5*log(r)*r/dr);
}

/* returns vec4: baseColor, distance */
vec4 distanceEstimator(vec3 p){
	//return de_sphere(p,0.2);
	//return de_sphereplane(p,0.2);
	//return de_abstractspace(p);
	//return de_recursive_thetrahedron(p);
	return de_mandlebulb(p);
}

vec3 calculate_normal(vec3 p, float dx){
	const vec3 k = vec3(1.,-1.,0.);
	return normalize(k.xyy * distanceEstimator(p + dx * k.xyy).w +
					 k.yyx * distanceEstimator(p + dx * k.yyx).w +
					 k.yxy * distanceEstimator(p + dx * k.yxy).w +
					 k.xxx * distanceEstimator(p + dx * k.xxx).w);

}

vec3 calculate_lighting(vec3 from, vec3 pos, float steps, float totaldistance){
	// Blinn-Phong shading. See: https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model
	vec3 xDir = vec3(1.,0.,0.);
	vec3 yDir = vec3(0.,1.,0.);
	vec3 zDir = vec3(0.,0.,-1.);
	vec3 fractal_normal = normalize(vec3(distanceEstimator(pos+xDir).w - distanceEstimator(pos-xDir).w,
					distanceEstimator(pos+yDir).w - distanceEstimator(pos-yDir).w,
					distanceEstimator(pos+zDir).w - distanceEstimator(pos-zDir).w));

	//vec3 fractal_normal = calculate_normal(pos,MINIMUM_DISTANCE * 10.);

	// vec3 lightDirection = normalize(LIGHT_POSITION - pos);
	vec3 lightDirection = LIGHT_DIRECTION;
	float lightDistance = pow(length(lightDirection),2.);

	float lambertian =  max (dot(lightDirection,fractal_normal),0.);
	vec3 viewDir = normalize (from - pos);
	vec3 halfDir =  normalize(lightDirection + viewDir);
	float specAngle = max(dot(halfDir, fractal_normal),0.);
	float specular = pow(specAngle,SHININESS);

	vec3 color = COLOR_AMBIENT + COLOR_DIFFUSE * lambertian + COLOR_SPECULAR * specular;

	// Add small amount of ambient occlusion
	float a = 1.0 / (1.0 + steps * AMBIENT_OCCLUSION_STRENGTH);
	color += (1.0 - a) * AMBIENT_OCCLUSION_COLOR_DELTA;

	// Add fog in distance
	a = totaldistance / 30.;
	color = (1.0 - a) * color + a * BACKGROUND_COLOR;


	return color;
}

vec3 ray_march(vec4 from, vec4 direction, out vec3 baseColor) {
	float distance = 0.0;
	float totalDistance = 0.0;
	float steps;
	for (steps=0.; steps < MAXIMUM_RAY_STEPS; steps++) {
		vec4 pos = from + totalDistance * direction;

		vec4 de = distanceEstimator(pos.xyz);
		distance = de.w;
		baseColor = de.xyz;

		totalDistance += distance;
		if (distance < MINIMUM_DISTANCE) break;
	}
	return vec3(distance, steps, totalDistance);
}

vec4 scene(inout vec4 origin, inout vec4 ray){
	vec3 color = vec3(0.);
	vec3 marched = ray_march(origin, ray, color);
	float distance = marched.x;
	float steps = marched.y;
	float totalDistance = marched.z;
	color /= 5.;

	if (distance < MINIMUM_DISTANCE){
		color += calculate_lighting(origin.xyz, ray.xyz, steps, totalDistance);
	}
	else {
		color = BACKGROUND_COLOR;

		// rendering sun
		float sun_spec = dot(ray.xyz, LIGHT_DIRECTION) - 1.0 + 0.005;
		sun_spec = min(exp(sun_spec * 2.0 / 0.005), 1.0);
		color += vec3(1., .9, -.2) * sun_spec;
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
