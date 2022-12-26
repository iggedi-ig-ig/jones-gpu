struct VertexInput {
    // per vertex inputs
    @location(0) position: vec2<f32>,
    @location(1) color: vec4<f32>,
    // per instance inputs
    @location(2) instance_position: vec2<f32>,
    @location(3) instance_velocity: vec2<f32>,
    @location(4) instance_force: vec2<f32>,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
}

struct PushConstants {
    position: vec2<f32>,
    inv_aspect: f32,
    scale: f32
}

var<push_constant> push_constants: PushConstants;

let radius = 1.0;

fn get_color(velocity_mag: f32) -> vec3<f32> {
let color_map = array<vec3<f32>, 256>(
            vec3<f32>(0.18995, 0.07176, 0.23217),
            vec3<f32>(0.19483, 0.08339, 0.26149),
            vec3<f32>(0.19956, 0.09498, 0.29024),
            vec3<f32>(0.20415, 0.10652, 0.31844),
            vec3<f32>(0.20860, 0.11802, 0.34607),
            vec3<f32>(0.21291, 0.12947, 0.37314),
            vec3<f32>(0.21708, 0.14087, 0.39964),
            vec3<f32>(0.22111, 0.15223, 0.42558),
            vec3<f32>(0.22500, 0.16354, 0.45096),
            vec3<f32>(0.22875, 0.17481, 0.47578),
            vec3<f32>(0.23236, 0.18603, 0.50004),
            vec3<f32>(0.23582, 0.19720, 0.52373),
            vec3<f32>(0.23915, 0.20833, 0.54686),
            vec3<f32>(0.24234, 0.21941, 0.56942),
            vec3<f32>(0.24539, 0.23044, 0.59142),
            vec3<f32>(0.24830, 0.24143, 0.61286),
            vec3<f32>(0.25107, 0.25237, 0.63374),
            vec3<f32>(0.25369, 0.26327, 0.65406),
            vec3<f32>(0.25618, 0.27412, 0.67381),
            vec3<f32>(0.25853, 0.28492, 0.69300),
            vec3<f32>(0.26074, 0.29568, 0.71162),
            vec3<f32>(0.26280, 0.30639, 0.72968),
            vec3<f32>(0.26473, 0.31706, 0.74718),
            vec3<f32>(0.26652, 0.32768, 0.76412),
            vec3<f32>(0.26816, 0.33825, 0.78050),
            vec3<f32>(0.26967, 0.34878, 0.79631),
            vec3<f32>(0.27103, 0.35926, 0.81156),
            vec3<f32>(0.27226, 0.36970, 0.82624),
            vec3<f32>(0.27334, 0.38008, 0.84037),
            vec3<f32>(0.27429, 0.39043, 0.85393),
            vec3<f32>(0.27509, 0.40072, 0.86692),
            vec3<f32>(0.27576, 0.41097, 0.87936),
            vec3<f32>(0.27628, 0.42118, 0.89123),
            vec3<f32>(0.27667, 0.43134, 0.90254),
            vec3<f32>(0.27691, 0.44145, 0.91328),
            vec3<f32>(0.27701, 0.45152, 0.92347),
            vec3<f32>(0.27698, 0.46153, 0.93309),
            vec3<f32>(0.27680, 0.47151, 0.94214),
            vec3<f32>(0.27648, 0.48144, 0.95064),
            vec3<f32>(0.27603, 0.49132, 0.95857),
            vec3<f32>(0.27543, 0.50115, 0.96594),
            vec3<f32>(0.27469, 0.51094, 0.97275),
            vec3<f32>(0.27381, 0.52069, 0.97899),
            vec3<f32>(0.27273, 0.53040, 0.98461),
            vec3<f32>(0.27106, 0.54015, 0.98930),
            vec3<f32>(0.26878, 0.54995, 0.99303),
            vec3<f32>(0.26592, 0.55979, 0.99583),
            vec3<f32>(0.26252, 0.56967, 0.99773),
            vec3<f32>(0.25862, 0.57958, 0.99876),
            vec3<f32>(0.25425, 0.58950, 0.99896),
            vec3<f32>(0.24946, 0.59943, 0.99835),
            vec3<f32>(0.24427, 0.60937, 0.99697),
            vec3<f32>(0.23874, 0.61931, 0.99485),
            vec3<f32>(0.23288, 0.62923, 0.99202),
            vec3<f32>(0.22676, 0.63913, 0.98851),
            vec3<f32>(0.22039, 0.64901, 0.98436),
            vec3<f32>(0.21382, 0.65886, 0.97959),
            vec3<f32>(0.20708, 0.66866, 0.97423),
            vec3<f32>(0.20021, 0.67842, 0.96833),
            vec3<f32>(0.19326, 0.68812, 0.96190),
            vec3<f32>(0.18625, 0.69775, 0.95498),
            vec3<f32>(0.17923, 0.70732, 0.94761),
            vec3<f32>(0.17223, 0.71680, 0.93981),
            vec3<f32>(0.16529, 0.72620, 0.93161),
            vec3<f32>(0.15844, 0.73551, 0.92305),
            vec3<f32>(0.15173, 0.74472, 0.91416),
            vec3<f32>(0.14519, 0.75381, 0.90496),
            vec3<f32>(0.13886, 0.76279, 0.89550),
            vec3<f32>(0.13278, 0.77165, 0.88580),
            vec3<f32>(0.12698, 0.78037, 0.87590),
            vec3<f32>(0.12151, 0.78896, 0.86581),
            vec3<f32>(0.11639, 0.79740, 0.85559),
            vec3<f32>(0.11167, 0.80569, 0.84525),
            vec3<f32>(0.10738, 0.81381, 0.83484),
            vec3<f32>(0.10357, 0.82177, 0.82437),
            vec3<f32>(0.10026, 0.82955, 0.81389),
            vec3<f32>(0.09750, 0.83714, 0.80342),
            vec3<f32>(0.09532, 0.84455, 0.79299),
            vec3<f32>(0.09377, 0.85175, 0.78264),
            vec3<f32>(0.09287, 0.85875, 0.77240),
            vec3<f32>(0.09267, 0.86554, 0.76230),
            vec3<f32>(0.09320, 0.87211, 0.75237),
            vec3<f32>(0.09451, 0.87844, 0.74265),
            vec3<f32>(0.09662, 0.88454, 0.73316),
            vec3<f32>(0.09958, 0.89040, 0.72393),
            vec3<f32>(0.10342, 0.89600, 0.71500),
            vec3<f32>(0.10815, 0.90142, 0.70599),
            vec3<f32>(0.11374, 0.90673, 0.69651),
            vec3<f32>(0.12014, 0.91193, 0.68660),
            vec3<f32>(0.12733, 0.91701, 0.67627),
            vec3<f32>(0.13526, 0.92197, 0.66556),
            vec3<f32>(0.14391, 0.92680, 0.65448),
            vec3<f32>(0.15323, 0.93151, 0.64308),
            vec3<f32>(0.16319, 0.93609, 0.63137),
            vec3<f32>(0.17377, 0.94053, 0.61938),
            vec3<f32>(0.18491, 0.94484, 0.60713),
            vec3<f32>(0.19659, 0.94901, 0.59466),
            vec3<f32>(0.20877, 0.95304, 0.58199),
            vec3<f32>(0.22142, 0.95692, 0.56914),
            vec3<f32>(0.23449, 0.96065, 0.55614),
            vec3<f32>(0.24797, 0.96423, 0.54303),
            vec3<f32>(0.26180, 0.96765, 0.52981),
            vec3<f32>(0.27597, 0.97092, 0.51653),
            vec3<f32>(0.29042, 0.97403, 0.50321),
            vec3<f32>(0.30513, 0.97697, 0.48987),
            vec3<f32>(0.32006, 0.97974, 0.47654),
            vec3<f32>(0.33517, 0.98234, 0.46325),
            vec3<f32>(0.35043, 0.98477, 0.45002),
            vec3<f32>(0.36581, 0.98702, 0.43688),
            vec3<f32>(0.38127, 0.98909, 0.42386),
            vec3<f32>(0.39678, 0.99098, 0.41098),
            vec3<f32>(0.41229, 0.99268, 0.39826),
            vec3<f32>(0.42778, 0.99419, 0.38575),
            vec3<f32>(0.44321, 0.99551, 0.37345),
            vec3<f32>(0.45854, 0.99663, 0.36140),
            vec3<f32>(0.47375, 0.99755, 0.34963),
            vec3<f32>(0.48879, 0.99828, 0.33816),
            vec3<f32>(0.50362, 0.99879, 0.32701),
            vec3<f32>(0.51822, 0.99910, 0.31622),
            vec3<f32>(0.53255, 0.99919, 0.30581),
            vec3<f32>(0.54658, 0.99907, 0.29581),
            vec3<f32>(0.56026, 0.99873, 0.28623),
            vec3<f32>(0.57357, 0.99817, 0.27712),
            vec3<f32>(0.58646, 0.99739, 0.26849),
            vec3<f32>(0.59891, 0.99638, 0.26038),
            vec3<f32>(0.61088, 0.99514, 0.25280),
            vec3<f32>(0.62233, 0.99366, 0.24579),
            vec3<f32>(0.63323, 0.99195, 0.23937),
            vec3<f32>(0.64362, 0.98999, 0.23356),
            vec3<f32>(0.65394, 0.98775, 0.22835),
            vec3<f32>(0.66428, 0.98524, 0.22370),
            vec3<f32>(0.67462, 0.98246, 0.21960),
            vec3<f32>(0.68494, 0.97941, 0.21602),
            vec3<f32>(0.69525, 0.97610, 0.21294),
            vec3<f32>(0.70553, 0.97255, 0.21032),
            vec3<f32>(0.71577, 0.96875, 0.20815),
            vec3<f32>(0.72596, 0.96470, 0.20640),
            vec3<f32>(0.73610, 0.96043, 0.20504),
            vec3<f32>(0.74617, 0.95593, 0.20406),
            vec3<f32>(0.75617, 0.95121, 0.20343),
            vec3<f32>(0.76608, 0.94627, 0.20311),
            vec3<f32>(0.77591, 0.94113, 0.20310),
            vec3<f32>(0.78563, 0.93579, 0.20336),
            vec3<f32>(0.79524, 0.93025, 0.20386),
            vec3<f32>(0.80473, 0.92452, 0.20459),
            vec3<f32>(0.81410, 0.91861, 0.20552),
            vec3<f32>(0.82333, 0.91253, 0.20663),
            vec3<f32>(0.83241, 0.90627, 0.20788),
            vec3<f32>(0.84133, 0.89986, 0.20926),
            vec3<f32>(0.85010, 0.89328, 0.21074),
            vec3<f32>(0.85868, 0.88655, 0.21230),
            vec3<f32>(0.86709, 0.87968, 0.21391),
            vec3<f32>(0.87530, 0.87267, 0.21555),
            vec3<f32>(0.88331, 0.86553, 0.21719),
            vec3<f32>(0.89112, 0.85826, 0.21880),
            vec3<f32>(0.89870, 0.85087, 0.22038),
            vec3<f32>(0.90605, 0.84337, 0.22188),
            vec3<f32>(0.91317, 0.83576, 0.22328),
            vec3<f32>(0.92004, 0.82806, 0.22456),
            vec3<f32>(0.92666, 0.82025, 0.22570),
            vec3<f32>(0.93301, 0.81236, 0.22667),
            vec3<f32>(0.93909, 0.80439, 0.22744),
            vec3<f32>(0.94489, 0.79634, 0.22800),
            vec3<f32>(0.95039, 0.78823, 0.22831),
            vec3<f32>(0.95560, 0.78005, 0.22836),
            vec3<f32>(0.96049, 0.77181, 0.22811),
            vec3<f32>(0.96507, 0.76352, 0.22754),
            vec3<f32>(0.96931, 0.75519, 0.22663),
            vec3<f32>(0.97323, 0.74682, 0.22536),
            vec3<f32>(0.97679, 0.73842, 0.22369),
            vec3<f32>(0.98000, 0.73000, 0.22161),
            vec3<f32>(0.98289, 0.72140, 0.21918),
            vec3<f32>(0.98549, 0.71250, 0.21650),
            vec3<f32>(0.98781, 0.70330, 0.21358),
            vec3<f32>(0.98986, 0.69382, 0.21043),
            vec3<f32>(0.99163, 0.68408, 0.20706),
            vec3<f32>(0.99314, 0.67408, 0.20348),
            vec3<f32>(0.99438, 0.66386, 0.19971),
            vec3<f32>(0.99535, 0.65341, 0.19577),
            vec3<f32>(0.99607, 0.64277, 0.19165),
            vec3<f32>(0.99654, 0.63193, 0.18738),
            vec3<f32>(0.99675, 0.62093, 0.18297),
            vec3<f32>(0.99672, 0.60977, 0.17842),
            vec3<f32>(0.99644, 0.59846, 0.17376),
            vec3<f32>(0.99593, 0.58703, 0.16899),
            vec3<f32>(0.99517, 0.57549, 0.16412),
            vec3<f32>(0.99419, 0.56386, 0.15918),
            vec3<f32>(0.99297, 0.55214, 0.15417),
            vec3<f32>(0.99153, 0.54036, 0.14910),
            vec3<f32>(0.98987, 0.52854, 0.14398),
            vec3<f32>(0.98799, 0.51667, 0.13883),
            vec3<f32>(0.98590, 0.50479, 0.13367),
            vec3<f32>(0.98360, 0.49291, 0.12849),
            vec3<f32>(0.98108, 0.48104, 0.12332),
            vec3<f32>(0.97837, 0.46920, 0.11817),
            vec3<f32>(0.97545, 0.45740, 0.11305),
            vec3<f32>(0.97234, 0.44565, 0.10797),
            vec3<f32>(0.96904, 0.43399, 0.10294),
            vec3<f32>(0.96555, 0.42241, 0.09798),
            vec3<f32>(0.96187, 0.41093, 0.09310),
            vec3<f32>(0.95801, 0.39958, 0.08831),
            vec3<f32>(0.95398, 0.38836, 0.08362),
            vec3<f32>(0.94977, 0.37729, 0.07905),
            vec3<f32>(0.94538, 0.36638, 0.07461),
            vec3<f32>(0.94084, 0.35566, 0.07031),
            vec3<f32>(0.93612, 0.34513, 0.06616),
            vec3<f32>(0.93125, 0.33482, 0.06218),
            vec3<f32>(0.92623, 0.32473, 0.05837),
            vec3<f32>(0.92105, 0.31489, 0.05475),
            vec3<f32>(0.91572, 0.30530, 0.05134),
            vec3<f32>(0.91024, 0.29599, 0.04814),
            vec3<f32>(0.90463, 0.28696, 0.04516),
            vec3<f32>(0.89888, 0.27824, 0.04243),
            vec3<f32>(0.89298, 0.26981, 0.03993),
            vec3<f32>(0.88691, 0.26152, 0.03753),
            vec3<f32>(0.88066, 0.25334, 0.03521),
            vec3<f32>(0.87422, 0.24526, 0.03297),
            vec3<f32>(0.86760, 0.23730, 0.03082),
            vec3<f32>(0.86079, 0.22945, 0.02875),
            vec3<f32>(0.85380, 0.22170, 0.02677),
            vec3<f32>(0.84662, 0.21407, 0.02487),
            vec3<f32>(0.83926, 0.20654, 0.02305),
            vec3<f32>(0.83172, 0.19912, 0.02131),
            vec3<f32>(0.82399, 0.19182, 0.01966),
            vec3<f32>(0.81608, 0.18462, 0.01809),
            vec3<f32>(0.80799, 0.17753, 0.01660),
            vec3<f32>(0.79971, 0.17055, 0.01520),
            vec3<f32>(0.79125, 0.16368, 0.01387),
            vec3<f32>(0.78260, 0.15693, 0.01264),
            vec3<f32>(0.77377, 0.15028, 0.01148),
            vec3<f32>(0.76476, 0.14374, 0.01041),
            vec3<f32>(0.75556, 0.13731, 0.00942),
            vec3<f32>(0.74617, 0.13098, 0.00851),
            vec3<f32>(0.73661, 0.12477, 0.00769),
            vec3<f32>(0.72686, 0.11867, 0.00695),
            vec3<f32>(0.71692, 0.11268, 0.00629),
            vec3<f32>(0.70680, 0.10680, 0.00571),
            vec3<f32>(0.69650, 0.10102, 0.00522),
            vec3<f32>(0.68602, 0.09536, 0.00481),
            vec3<f32>(0.67535, 0.08980, 0.00449),
            vec3<f32>(0.66449, 0.08436, 0.00424),
            vec3<f32>(0.65345, 0.07902, 0.00408),
            vec3<f32>(0.64223, 0.07380, 0.00401),
            vec3<f32>(0.63082, 0.06868, 0.00401),
            vec3<f32>(0.61923, 0.06367, 0.00410),
            vec3<f32>(0.60746, 0.05878, 0.00427),
            vec3<f32>(0.59550, 0.05399, 0.00453),
            vec3<f32>(0.58336, 0.04931, 0.00486),
            vec3<f32>(0.57103, 0.04474, 0.00529),
            vec3<f32>(0.55852, 0.04028, 0.00579),
            vec3<f32>(0.54583, 0.03593, 0.00638),
            vec3<f32>(0.53295, 0.03169, 0.00705),
            vec3<f32>(0.51989, 0.02756, 0.00780),
            vec3<f32>(0.50664, 0.02354, 0.00863),
            vec3<f32>(0.49321, 0.01963, 0.00955),
            vec3<f32>(0.47960, 0.01583, 0.01055),
       );

    let colormap_idx = min(i32(floor(velocity_mag * 25.0)), 255);
     if (colormap_idx == 0) { return color_map[0]; }
     if (colormap_idx == 1) { return color_map[1]; }
     if (colormap_idx == 2) { return color_map[2]; }
     if (colormap_idx == 3) { return color_map[3]; }
     if (colormap_idx == 4) { return color_map[4]; }
     if (colormap_idx == 5) { return color_map[5]; }
     if (colormap_idx == 6) { return color_map[6]; }
     if (colormap_idx == 7) { return color_map[7]; }
     if (colormap_idx == 8) { return color_map[8]; }
     if (colormap_idx == 9) { return color_map[9]; }
     if (colormap_idx == 10) { return color_map[10]; }
     if (colormap_idx == 11) { return color_map[11]; }
     if (colormap_idx == 12) { return color_map[12]; }
     if (colormap_idx == 13) { return color_map[13]; }
     if (colormap_idx == 14) { return color_map[14]; }
     if (colormap_idx == 15) { return color_map[15]; }
     if (colormap_idx == 16) { return color_map[16]; }
     if (colormap_idx == 17) { return color_map[17]; }
     if (colormap_idx == 18) { return color_map[18]; }
     if (colormap_idx == 19) { return color_map[19]; }
     if (colormap_idx == 20) { return color_map[20]; }
     if (colormap_idx == 21) { return color_map[21]; }
     if (colormap_idx == 22) { return color_map[22]; }
     if (colormap_idx == 23) { return color_map[23]; }
     if (colormap_idx == 24) { return color_map[24]; }
     if (colormap_idx == 25) { return color_map[25]; }
     if (colormap_idx == 26) { return color_map[26]; }
     if (colormap_idx == 27) { return color_map[27]; }
     if (colormap_idx == 28) { return color_map[28]; }
     if (colormap_idx == 29) { return color_map[29]; }
     if (colormap_idx == 30) { return color_map[30]; }
     if (colormap_idx == 31) { return color_map[31]; }
     if (colormap_idx == 32) { return color_map[32]; }
     if (colormap_idx == 33) { return color_map[33]; }
     if (colormap_idx == 34) { return color_map[34]; }
     if (colormap_idx == 35) { return color_map[35]; }
     if (colormap_idx == 36) { return color_map[36]; }
     if (colormap_idx == 37) { return color_map[37]; }
     if (colormap_idx == 38) { return color_map[38]; }
     if (colormap_idx == 39) { return color_map[39]; }
     if (colormap_idx == 40) { return color_map[40]; }
     if (colormap_idx == 41) { return color_map[41]; }
     if (colormap_idx == 42) { return color_map[42]; }
     if (colormap_idx == 43) { return color_map[43]; }
     if (colormap_idx == 44) { return color_map[44]; }
     if (colormap_idx == 45) { return color_map[45]; }
     if (colormap_idx == 46) { return color_map[46]; }
     if (colormap_idx == 47) { return color_map[47]; }
     if (colormap_idx == 48) { return color_map[48]; }
     if (colormap_idx == 49) { return color_map[49]; }
     if (colormap_idx == 50) { return color_map[50]; }
     if (colormap_idx == 51) { return color_map[51]; }
     if (colormap_idx == 52) { return color_map[52]; }
     if (colormap_idx == 53) { return color_map[53]; }
     if (colormap_idx == 54) { return color_map[54]; }
     if (colormap_idx == 55) { return color_map[55]; }
     if (colormap_idx == 56) { return color_map[56]; }
     if (colormap_idx == 57) { return color_map[57]; }
     if (colormap_idx == 58) { return color_map[58]; }
     if (colormap_idx == 59) { return color_map[59]; }
     if (colormap_idx == 60) { return color_map[60]; }
     if (colormap_idx == 61) { return color_map[61]; }
     if (colormap_idx == 62) { return color_map[62]; }
     if (colormap_idx == 63) { return color_map[63]; }
     if (colormap_idx == 64) { return color_map[64]; }
     if (colormap_idx == 65) { return color_map[65]; }
     if (colormap_idx == 66) { return color_map[66]; }
     if (colormap_idx == 67) { return color_map[67]; }
     if (colormap_idx == 68) { return color_map[68]; }
     if (colormap_idx == 69) { return color_map[69]; }
     if (colormap_idx == 70) { return color_map[70]; }
     if (colormap_idx == 71) { return color_map[71]; }
     if (colormap_idx == 72) { return color_map[72]; }
     if (colormap_idx == 73) { return color_map[73]; }
     if (colormap_idx == 74) { return color_map[74]; }
     if (colormap_idx == 75) { return color_map[75]; }
     if (colormap_idx == 76) { return color_map[76]; }
     if (colormap_idx == 77) { return color_map[77]; }
     if (colormap_idx == 78) { return color_map[78]; }
     if (colormap_idx == 79) { return color_map[79]; }
     if (colormap_idx == 80) { return color_map[80]; }
     if (colormap_idx == 81) { return color_map[81]; }
     if (colormap_idx == 82) { return color_map[82]; }
     if (colormap_idx == 83) { return color_map[83]; }
     if (colormap_idx == 84) { return color_map[84]; }
     if (colormap_idx == 85) { return color_map[85]; }
     if (colormap_idx == 86) { return color_map[86]; }
     if (colormap_idx == 87) { return color_map[87]; }
     if (colormap_idx == 88) { return color_map[88]; }
     if (colormap_idx == 89) { return color_map[89]; }
     if (colormap_idx == 90) { return color_map[90]; }
     if (colormap_idx == 91) { return color_map[91]; }
     if (colormap_idx == 92) { return color_map[92]; }
     if (colormap_idx == 93) { return color_map[93]; }
     if (colormap_idx == 94) { return color_map[94]; }
     if (colormap_idx == 95) { return color_map[95]; }
     if (colormap_idx == 96) { return color_map[96]; }
     if (colormap_idx == 97) { return color_map[97]; }
     if (colormap_idx == 98) { return color_map[98]; }
     if (colormap_idx == 99) { return color_map[99]; }
     if (colormap_idx == 100) { return color_map[100]; }
     if (colormap_idx == 101) { return color_map[101]; }
     if (colormap_idx == 102) { return color_map[102]; }
     if (colormap_idx == 103) { return color_map[103]; }
     if (colormap_idx == 104) { return color_map[104]; }
     if (colormap_idx == 105) { return color_map[105]; }
     if (colormap_idx == 106) { return color_map[106]; }
     if (colormap_idx == 107) { return color_map[107]; }
     if (colormap_idx == 108) { return color_map[108]; }
     if (colormap_idx == 109) { return color_map[109]; }
     if (colormap_idx == 110) { return color_map[110]; }
     if (colormap_idx == 111) { return color_map[111]; }
     if (colormap_idx == 112) { return color_map[112]; }
     if (colormap_idx == 113) { return color_map[113]; }
     if (colormap_idx == 114) { return color_map[114]; }
     if (colormap_idx == 115) { return color_map[115]; }
     if (colormap_idx == 116) { return color_map[116]; }
     if (colormap_idx == 117) { return color_map[117]; }
     if (colormap_idx == 118) { return color_map[118]; }
     if (colormap_idx == 119) { return color_map[119]; }
     if (colormap_idx == 120) { return color_map[120]; }
     if (colormap_idx == 121) { return color_map[121]; }
     if (colormap_idx == 122) { return color_map[122]; }
     if (colormap_idx == 123) { return color_map[123]; }
     if (colormap_idx == 124) { return color_map[124]; }
     if (colormap_idx == 125) { return color_map[125]; }
     if (colormap_idx == 126) { return color_map[126]; }
     if (colormap_idx == 127) { return color_map[127]; }
     if (colormap_idx == 128) { return color_map[128]; }
     if (colormap_idx == 129) { return color_map[129]; }
     if (colormap_idx == 130) { return color_map[130]; }
     if (colormap_idx == 131) { return color_map[131]; }
     if (colormap_idx == 132) { return color_map[132]; }
     if (colormap_idx == 133) { return color_map[133]; }
     if (colormap_idx == 134) { return color_map[134]; }
     if (colormap_idx == 135) { return color_map[135]; }
     if (colormap_idx == 136) { return color_map[136]; }
     if (colormap_idx == 137) { return color_map[137]; }
     if (colormap_idx == 138) { return color_map[138]; }
     if (colormap_idx == 139) { return color_map[139]; }
     if (colormap_idx == 140) { return color_map[140]; }
     if (colormap_idx == 141) { return color_map[141]; }
     if (colormap_idx == 142) { return color_map[142]; }
     if (colormap_idx == 143) { return color_map[143]; }
     if (colormap_idx == 144) { return color_map[144]; }
     if (colormap_idx == 145) { return color_map[145]; }
     if (colormap_idx == 146) { return color_map[146]; }
     if (colormap_idx == 147) { return color_map[147]; }
     if (colormap_idx == 148) { return color_map[148]; }
     if (colormap_idx == 149) { return color_map[149]; }
     if (colormap_idx == 150) { return color_map[150]; }
     if (colormap_idx == 151) { return color_map[151]; }
     if (colormap_idx == 152) { return color_map[152]; }
     if (colormap_idx == 153) { return color_map[153]; }
     if (colormap_idx == 154) { return color_map[154]; }
     if (colormap_idx == 155) { return color_map[155]; }
     if (colormap_idx == 156) { return color_map[156]; }
     if (colormap_idx == 157) { return color_map[157]; }
     if (colormap_idx == 158) { return color_map[158]; }
     if (colormap_idx == 159) { return color_map[159]; }
     if (colormap_idx == 160) { return color_map[160]; }
     if (colormap_idx == 161) { return color_map[161]; }
     if (colormap_idx == 162) { return color_map[162]; }
     if (colormap_idx == 163) { return color_map[163]; }
     if (colormap_idx == 164) { return color_map[164]; }
     if (colormap_idx == 165) { return color_map[165]; }
     if (colormap_idx == 166) { return color_map[166]; }
     if (colormap_idx == 167) { return color_map[167]; }
     if (colormap_idx == 168) { return color_map[168]; }
     if (colormap_idx == 169) { return color_map[169]; }
     if (colormap_idx == 170) { return color_map[170]; }
     if (colormap_idx == 171) { return color_map[171]; }
     if (colormap_idx == 172) { return color_map[172]; }
     if (colormap_idx == 173) { return color_map[173]; }
     if (colormap_idx == 174) { return color_map[174]; }
     if (colormap_idx == 175) { return color_map[175]; }
     if (colormap_idx == 176) { return color_map[176]; }
     if (colormap_idx == 177) { return color_map[177]; }
     if (colormap_idx == 178) { return color_map[178]; }
     if (colormap_idx == 179) { return color_map[179]; }
     if (colormap_idx == 180) { return color_map[180]; }
     if (colormap_idx == 181) { return color_map[181]; }
     if (colormap_idx == 182) { return color_map[182]; }
     if (colormap_idx == 183) { return color_map[183]; }
     if (colormap_idx == 184) { return color_map[184]; }
     if (colormap_idx == 185) { return color_map[185]; }
     if (colormap_idx == 186) { return color_map[186]; }
     if (colormap_idx == 187) { return color_map[187]; }
     if (colormap_idx == 188) { return color_map[188]; }
     if (colormap_idx == 189) { return color_map[189]; }
     if (colormap_idx == 190) { return color_map[190]; }
     if (colormap_idx == 191) { return color_map[191]; }
     if (colormap_idx == 192) { return color_map[192]; }
     if (colormap_idx == 193) { return color_map[193]; }
     if (colormap_idx == 194) { return color_map[194]; }
     if (colormap_idx == 195) { return color_map[195]; }
     if (colormap_idx == 196) { return color_map[196]; }
     if (colormap_idx == 197) { return color_map[197]; }
     if (colormap_idx == 198) { return color_map[198]; }
     if (colormap_idx == 199) { return color_map[199]; }
     if (colormap_idx == 200) { return color_map[200]; }
     if (colormap_idx == 201) { return color_map[201]; }
     if (colormap_idx == 202) { return color_map[202]; }
     if (colormap_idx == 203) { return color_map[203]; }
     if (colormap_idx == 204) { return color_map[204]; }
     if (colormap_idx == 205) { return color_map[205]; }
     if (colormap_idx == 206) { return color_map[206]; }
     if (colormap_idx == 207) { return color_map[207]; }
     if (colormap_idx == 208) { return color_map[208]; }
     if (colormap_idx == 209) { return color_map[209]; }
     if (colormap_idx == 210) { return color_map[210]; }
     if (colormap_idx == 211) { return color_map[211]; }
     if (colormap_idx == 212) { return color_map[212]; }
     if (colormap_idx == 213) { return color_map[213]; }
     if (colormap_idx == 214) { return color_map[214]; }
     if (colormap_idx == 215) { return color_map[215]; }
     if (colormap_idx == 216) { return color_map[216]; }
     if (colormap_idx == 217) { return color_map[217]; }
     if (colormap_idx == 218) { return color_map[218]; }
     if (colormap_idx == 219) { return color_map[219]; }
     if (colormap_idx == 220) { return color_map[220]; }
     if (colormap_idx == 221) { return color_map[221]; }
     if (colormap_idx == 222) { return color_map[222]; }
     if (colormap_idx == 223) { return color_map[223]; }
     if (colormap_idx == 224) { return color_map[224]; }
     if (colormap_idx == 225) { return color_map[225]; }
     if (colormap_idx == 226) { return color_map[226]; }
     if (colormap_idx == 227) { return color_map[227]; }
     if (colormap_idx == 228) { return color_map[228]; }
     if (colormap_idx == 229) { return color_map[229]; }
     if (colormap_idx == 230) { return color_map[230]; }
     if (colormap_idx == 231) { return color_map[231]; }
     if (colormap_idx == 232) { return color_map[232]; }
     if (colormap_idx == 233) { return color_map[233]; }
     if (colormap_idx == 234) { return color_map[234]; }
     if (colormap_idx == 235) { return color_map[235]; }
     if (colormap_idx == 236) { return color_map[236]; }
     if (colormap_idx == 237) { return color_map[237]; }
     if (colormap_idx == 238) { return color_map[238]; }
     if (colormap_idx == 239) { return color_map[239]; }
     if (colormap_idx == 240) { return color_map[240]; }
     if (colormap_idx == 241) { return color_map[241]; }
     if (colormap_idx == 242) { return color_map[242]; }
     if (colormap_idx == 243) { return color_map[243]; }
     if (colormap_idx == 244) { return color_map[244]; }
     if (colormap_idx == 245) { return color_map[245]; }
     if (colormap_idx == 246) { return color_map[246]; }
     if (colormap_idx == 247) { return color_map[247]; }
     if (colormap_idx == 248) { return color_map[248]; }
     if (colormap_idx == 249) { return color_map[249]; }
     if (colormap_idx == 250) { return color_map[250]; }
     if (colormap_idx == 251) { return color_map[251]; }
     if (colormap_idx == 252) { return color_map[252]; }
     if (colormap_idx == 253) { return color_map[253]; }
     if (colormap_idx == 254) { return color_map[254]; }
     return color_map[255];
 }

@vertex
fn main_vs(vs_inputs: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    out.position = vec4<f32>(
        (vs_inputs.position * radius - push_constants.position + vs_inputs.instance_position) * vec2<f32>(push_constants.inv_aspect, 1.0) * push_constants.scale,
            0.0,
            1.0);
    let velocity_mag = length(vs_inputs.instance_force);
    out.color = vs_inputs.color * vec4<f32>(get_color(velocity_mag), 1.0);
    return out;
}

@fragment
fn main_fs(in: VertexOutput) -> @location(0) vec4<f32> {
    return in.color;
}