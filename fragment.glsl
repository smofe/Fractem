#version 120

uniform vec2 u_resolution;

void main(void)
{
    vec2 uv = gl_FragCoord.xy / u_resolution;

    float c_re = mix(-2.555,1.,uv.x);
    float c_im = mix(-1.,1.,uv.y);
    float x = 0.;
    float y = 0.;
    float iterations = 0.;
    float max_iterations = 1000;

    while (x*x+y*y < 4. && iterations < max_iterations){
        float x_new = x*x-y*y+c_re;
        y = 2.*x*y+c_im;
        x = x_new;
        iterations++;
    }

    if (iterations < max_iterations) {
        gl_FragColor = vec4(iterations*3./max_iterations, iterations/max_iterations, iterations*2./max_iterations, 1.0);
    } else {
        gl_FragColor = vec4(0.0,0.0,0.0,1.0);
    }

}

