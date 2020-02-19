#version 120

const float MaximumRaySteps = 100.;
const float MinimumDistance = 0.00002;
const float Scale = 2.;
const float Iterations = 20;
const float Bailout = 5.;
const float Power = 1.2;
const vec3 Offset = vec3(.5,.5,1.);

// Lighting constants
const vec3 lightPosition = vec3(1.,-2.,-30.);
const vec3 ambientColor = vec3(0.1,0.1,0.1);
const vec3 diffuseColor = vec3(.5,.5,.2);
const vec3 specColor = vec3(1.,1.,1.);
const float shininess = 8.;

uniform vec2 u_resolution;
uniform vec3 u_camera_position;

float distanceEstimator(vec3 z){
	//return abs(length(p)-0.2);
	//return min( length(p)-0.1 , length(p-vec3(.2,0.0,0.0))-.1 );
	/*z.xy = mod((z.xy),1.0)-vec2(0.5); // instance on xy-plane
	z.xy /= 50.;
	return length(z)-0.003;             // sphere DE */

	/*vec3 a1 = vec3(.1,.1,.1);
	vec3 a2 = vec3(-.1,-.1,.1);
	vec3 a3 = vec3(.1,-.1,-.1);
	vec3 a4 = vec3(-.1,.1,-.1);
	vec3 c;
	int n = 0;
	float dist, d;
	while (n < Iterations) {
		 c = a1; dist = length(z-a1);
	        d = length(z-a2); if (d < dist) { c = a2; dist=d; }
		 d = length(z-a3); if (d < dist) { c = a3; dist=d; }
		 d = length(z-a4); if (d < dist) { c = a4; dist=d; }
		z = Scale*z-c*(Scale-1.0);
		n++;
	}

	return length(z) * pow(Scale, float(-n)); */

	float r;
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

vec3 trace(vec3 from, vec3 direction) {
	float totalDistance = 0.0;
	int steps;

	vec3 color;
	for (steps=0; steps < MaximumRaySteps; steps++) {
		vec3 pos = from + totalDistance * direction;

		color = calculate_lighting(from, pos);

		float distance = distanceEstimator(pos);
		totalDistance += distance;
		if (distance < MinimumDistance) break;
	}
	return (1.0-float(steps)/float(MaximumRaySteps)) * color;
}



void main(void)
{
	// map screen coordiante to [-1..1] and correct aspect ratio
    vec2 uv = gl_FragCoord.xy / u_resolution;
	uv = uv * 2. - 1.;
	uv *= u_resolution / u_resolution.x;

	vec3 direction = normalize(vec3(vec3(uv,0.)-u_camera_position));
	vec3 marched_color = trace(u_camera_position,direction);


	gl_FragColor = vec4(marched_color,1.);
}
