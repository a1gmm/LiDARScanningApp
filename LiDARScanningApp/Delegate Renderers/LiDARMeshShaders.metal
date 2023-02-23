#include <metal_stdlib>
using namespace metal;

typedef struct {
  float4x4 projectionTransform;
} VertexUniforms;

typedef struct {
  float4 position [[position, invariant]];
} VertexInOut;

[[kernel]]
void prepareMeshIndices(
  device uint3* input_indices [[buffer(0)]],
  device uint2* output_line_indices [[buffer(1)]],
  device packed_uint3 *output_triangle_indices [[buffer(2)]],
  uint tid [[thread_position_in_grid]]
) {
  uint triangle_id = tid / 3;
  uint id_in_triangle = tid % 3;
  uint next_id_in_triangle = (id_in_triangle + 1) % 3;
  
  uint3 triangle_indices = input_indices[triangle_id];
  uint2 line_indices(triangle_indices[id_in_triangle],
                     triangle_indices[next_id_in_triangle]);
  
  output_line_indices[tid] = line_indices;
  if (id_in_triangle == 0) {
    output_triangle_indices[triangle_id] = triangle_indices;
  }
}

[[vertex]]
VertexInOut lidarMeshVertexTransform(
  constant VertexUniforms &vertexUniforms [[buffer(0)]],
  const device float3 *vertices [[buffer(1)]],
  uint vid [[vertex_id]]
) {
  float4 position =
    vertexUniforms.projectionTransform * float4(vertices[vid], 1);
  return { position };
}

typedef struct {
  half4 color [[color(0)]];
} FragmentOut;

[[fragment]]
FragmentOut lidarMeshLineFragmentShader(
  VertexInOut in [[stage_in]]//,
) {
  return { half4(0, 1, 0, 0) };
}
