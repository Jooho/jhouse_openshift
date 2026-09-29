r"""
Compile-time auto-tuning block: 

import torch
from math import inf, nan
from torch._dynamo.testing import rand_strided
from torch._dynamo.utils import preserve_rng_state
from torch._inductor.select_algorithm import AlgorithmSelectorCache
from torch._inductor.async_compile import AsyncCompile

async_compile = AsyncCompile()
generate_example_value = AlgorithmSelectorCache.generate_example_value
empty_strided_cuda = torch._C._dynamo.guards._empty_strided_cuda
empty_strided_xpu = torch._C._dynamo.guards._empty_strided_xpu
get_raw_stream = torch._C._cuda_getCurrentRawStream


# kernel path: /tmp/vllm/torch_compile_cache/torch_aot_compile/a9abc970d7110a0f12ab2a3b78291046a3d34468864aa5fea9dc43aff6f67809/inductor_cache/sk/csk7hx3auy7nyiiin6wipd6q55gktiuvenlqghfqrhz7v54q6eq3.py
# Topologically Sorted Source Nodes: [add, layer_norm], Original ATen: [aten.add, aten.native_layer_norm]
# Source node to ATen node mapping:
#   add => add_6
#   layer_norm => add_10, add_11, convert_element_type_3, convert_element_type_4, mul_8, mul_9, rsqrt, sub_3, var_mean
# Graph fragment:
#   %arg4_1 : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=arg4_1]
#   %addmm : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=addmm]
#   %getitem_1 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=getitem_1]
#   %buf2 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=buf2]
#   %arg5_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg5_1]
#   %arg6_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg6_1]
#   %add_6 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.aten.add.Tensor](args = (%arg4_1, %addmm), kwargs = {})
#   %convert_element_type_3 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_6, torch.float32), kwargs = {})
#   %var_mean : [num_users=2] = call_function[target=torch.ops.aten.var_mean.correction](args = (%convert_element_type_3, [1]), kwargs = {correction: 0, keepdim: True})
#   %sub_3 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.sub.Tensor](args = (%convert_element_type_3, %getitem_1), kwargs = {})
#   %add_10 : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%getitem, 1e-05), kwargs = {})
#   %rsqrt : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.rsqrt.default](args = (%add_10,), kwargs = {})
#   %mul_8 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%sub_3, %rsqrt), kwargs = {})
#   %mul_9 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%mul_8, %arg5_1), kwargs = {})
#   %add_11 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%mul_9, %arg6_1), kwargs = {})
#   %convert_element_type_4 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_11, torch.float16), kwargs = {})
#   return %getitem_1,%buf2,%convert_element_type_4
triton_per_fused_add_native_layer_norm_0 = async_compile.triton('triton_per_fused_add_native_layer_norm_0', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.persistent_reduction(
    size_hints={'x': 2048, 'r0_': 1024},
    reduction_hint=ReductionHint.INNER,
    filename=__file__,
    triton_meta={'signature': {'in_ptr0': '*fp16', 'in_ptr1': '*fp16', 'in_ptr2': '*fp16', 'in_ptr3': '*fp16', 'out_ptr2': '*fp16', 'xnumel': 'i32', 'r0_numel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=142, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]], (2,): [['tt.divisibility', 16]], (3,): [['tt.divisibility', 16]], (4,): [['tt.divisibility', 16]], (6,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_per_fused_add_native_layer_norm_0', 'mutated_arg_names': [], 'optimize_mem': True, 'no_x_dim': None, 'atomic_add_found': False, 'num_load': 4, 'num_store': 1, 'num_reduction': 4, 'autotune_hints': set(), 'tiling_scores': {'x': 0, 'r0_': 12585984}, 'kernel_num_gb': 0.009440256, 'kernel_flop': 0, 'backend_hash': 'B2C00AD225F1945839503C666727F7E33E52219DAB5FB3E9C1893C177F82CD58', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False}
)
@triton.jit
def triton_per_fused_add_native_layer_norm_0(in_ptr0, in_ptr1, in_ptr2, in_ptr3, out_ptr2, xnumel, r0_numel, XBLOCK : tl.constexpr):
    r0_numel = 768
    R0_BLOCK: tl.constexpr = 1024
    rnumel = r0_numel
    RBLOCK: tl.constexpr = R0_BLOCK
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:, None]
    xmask = xindex < xnumel
    r0_index = tl.arange(0, R0_BLOCK)[None, :]
    r0_offset = 0
    r0_mask = r0_index < r0_numel
    roffset = r0_offset
    rindex = r0_index
    r0_1 = r0_index
    x0 = xindex
    tmp0 = tl.load(in_ptr0 + (r0_1 + 768*x0), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp1 = tl.load(in_ptr1 + (r0_1 + 768*x0), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp26 = tl.load(in_ptr2 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp29 = tl.load(in_ptr3 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp2 = tmp0 + tmp1
    tmp3 = tmp2.to(tl.float32)
    tmp4 = tl.broadcast_to(tmp3, [XBLOCK, R0_BLOCK])
    tmp6 = tl.where(r0_mask & xmask, tmp4, 0)
    tmp7 = tl.broadcast_to(tmp4, [XBLOCK, R0_BLOCK])
    tmp9 = tl.where(r0_mask & xmask, tmp7, 0)
    tmp10 = tl.sum(tmp9, 1)[:, None].to(tl.float32)
    tmp11 = (tl.full([1, 1], 768, tl.int32)).to(tl.float32)
    tmp12 = (tmp10 / tmp11)
    tmp13 = tmp4 - tmp12
    tmp14 = tmp13 * tmp13
    tmp15 = tl.broadcast_to(tmp14, [XBLOCK, R0_BLOCK])
    tmp17 = tl.where(r0_mask & xmask, tmp15, 0)
    tmp18 = tl.sum(tmp17, 1)[:, None].to(tl.float32)
    tmp19 = tmp3 - tmp12
    tmp20 = tl.full([1, 1], 768.0, tl.float32)
    tmp21 = (tmp18 / tmp20)
    tmp22 = tl.full([1, 1], 1e-05, tl.float32)
    tmp23 = tmp21 + tmp22
    tmp24 = libdevice.rsqrt(tmp23)
    tmp25 = tmp19 * tmp24
    tmp27 = tmp26.to(tl.float32)
    tmp28 = tmp25 * tmp27
    tmp30 = tmp29.to(tl.float32)
    tmp31 = tmp28 + tmp30
    tmp32 = tmp31.to(tl.float32)
    tl.store(out_ptr2 + (r0_1 + 768*x0), tmp32, r0_mask & xmask)
''', device_str='cuda')


# kernel path: /tmp/vllm/torch_compile_cache/torch_aot_compile/a9abc970d7110a0f12ab2a3b78291046a3d34468864aa5fea9dc43aff6f67809/inductor_cache/3k/c3kwmthm7mm6loqkfvah7pf5boslbb73za6zm3bm6vqsxr54ydpj.py
# Topologically Sorted Source Nodes: [relu], Original ATen: [aten.relu]
# Source node to ATen node mapping:
#   relu => relu
# Graph fragment:
#   %addmm_1 : Tensor "f16[s72, 3072][3072, 1]cuda:0" = PlaceHolder[target=addmm_1]
#   %relu : Tensor "f16[s72, 3072][3072, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.relu.default](args = (%addmm_1,), kwargs = {})
#   return %relu
triton_poi_fused_relu_1 = async_compile.triton('triton_poi_fused_relu_1', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.pointwise(
    size_hints={'x': 8388608}, 
    filename=__file__,
    triton_meta={'signature': {'in_out_ptr0': '*fp16', 'xnumel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=142, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_poi_fused_relu_1', 'mutated_arg_names': ['in_out_ptr0'], 'optimize_mem': True, 'no_x_dim': False, 'atomic_add_found': False, 'num_load': 1, 'num_store': 1, 'num_reduction': 0, 'autotune_hints': set(), 'tiling_scores': {'x': 37748736}, 'kernel_num_gb': 0.025165824, 'kernel_flop': 0, 'backend_hash': 'B2C00AD225F1945839503C666727F7E33E52219DAB5FB3E9C1893C177F82CD58', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False},
    min_elem_per_thread=0
)
@triton.jit
def triton_poi_fused_relu_1(in_out_ptr0, xnumel, XBLOCK : tl.constexpr):
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:]
    xmask = xindex < xnumel
    x0 = xindex
    tmp0 = tl.load(in_out_ptr0 + (x0), xmask).to(tl.float32)
    tmp1 = tl.full([1], 0, tl.int32)
    tmp2 = triton_helpers.maximum(tmp1, tmp0)
    tl.store(in_out_ptr0 + (x0), tmp2, xmask)
''', device_str='cuda')


# kernel path: /tmp/vllm/torch_compile_cache/torch_aot_compile/a9abc970d7110a0f12ab2a3b78291046a3d34468864aa5fea9dc43aff6f67809/inductor_cache/jv/cjvhk3kzhrdgyyoztjvvm3m7n4ixjmafyqrqwaogliihzeut7pmd.py
# Topologically Sorted Source Nodes: [add, add_1, layer_norm_1], Original ATen: [aten.add, aten.native_layer_norm]
# Source node to ATen node mapping:
#   add => add_6
#   add_1 => add_30
#   layer_norm_1 => add_34, add_35, convert_element_type_11, convert_element_type_12, mul_24, mul_25, rsqrt_1, sub_11, var_mean_1
# Graph fragment:
#   %arg4_1 : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=arg4_1]
#   %addmm : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=addmm]
#   %addmm_2 : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=addmm_2]
#   %getitem_3 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=getitem_3]
#   %buf9 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=buf9]
#   %arg11_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg11_1]
#   %arg12_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg12_1]
#   %add_6 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.aten.add.Tensor](args = (%arg4_1, %addmm), kwargs = {})
#   %add_30 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%add_6, %addmm_2), kwargs = {})
#   %convert_element_type_11 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_30, torch.float32), kwargs = {})
#   %var_mean_1 : [num_users=2] = call_function[target=torch.ops.aten.var_mean.correction](args = (%convert_element_type_11, [1]), kwargs = {correction: 0, keepdim: True})
#   %sub_11 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.sub.Tensor](args = (%convert_element_type_11, %getitem_3), kwargs = {})
#   %add_34 : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%getitem_2, 1e-05), kwargs = {})
#   %rsqrt_1 : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.rsqrt.default](args = (%add_34,), kwargs = {})
#   %mul_24 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%sub_11, %rsqrt_1), kwargs = {})
#   %mul_25 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%mul_24, %arg11_1), kwargs = {})
#   %add_35 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%mul_25, %arg12_1), kwargs = {})
#   %convert_element_type_12 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_35, torch.float16), kwargs = {})
#   return %getitem_3,%buf9,%convert_element_type_12
triton_per_fused_add_native_layer_norm_2 = async_compile.triton('triton_per_fused_add_native_layer_norm_2', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.persistent_reduction(
    size_hints={'x': 2048, 'r0_': 1024},
    reduction_hint=ReductionHint.INNER,
    filename=__file__,
    triton_meta={'signature': {'in_out_ptr0': '*fp16', 'in_ptr0': '*fp16', 'in_ptr1': '*fp16', 'in_ptr2': '*fp16', 'in_ptr3': '*fp16', 'xnumel': 'i32', 'r0_numel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=142, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]], (2,): [['tt.divisibility', 16]], (3,): [['tt.divisibility', 16]], (4,): [['tt.divisibility', 16]], (6,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_per_fused_add_native_layer_norm_2', 'mutated_arg_names': ['in_out_ptr0'], 'optimize_mem': True, 'no_x_dim': None, 'atomic_add_found': False, 'num_load': 5, 'num_store': 1, 'num_reduction': 4, 'autotune_hints': set(), 'tiling_scores': {'x': 0, 'r0_': 15731712}, 'kernel_num_gb': 0.012585984, 'kernel_flop': 0, 'backend_hash': 'B2C00AD225F1945839503C666727F7E33E52219DAB5FB3E9C1893C177F82CD58', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False}
)
@triton.jit
def triton_per_fused_add_native_layer_norm_2(in_out_ptr0, in_ptr0, in_ptr1, in_ptr2, in_ptr3, xnumel, r0_numel, XBLOCK : tl.constexpr):
    r0_numel = 768
    R0_BLOCK: tl.constexpr = 1024
    rnumel = r0_numel
    RBLOCK: tl.constexpr = R0_BLOCK
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:, None]
    xmask = xindex < xnumel
    r0_index = tl.arange(0, R0_BLOCK)[None, :]
    r0_offset = 0
    r0_mask = r0_index < r0_numel
    roffset = r0_offset
    rindex = r0_index
    r0_1 = r0_index
    x0 = xindex
    tmp0 = tl.load(in_ptr0 + (r0_1 + 768*x0), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp1 = tl.load(in_out_ptr0 + (r0_1 + 768*x0), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp3 = tl.load(in_ptr1 + (r0_1 + 768*x0), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp28 = tl.load(in_ptr2 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp31 = tl.load(in_ptr3 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp2 = tmp0 + tmp1
    tmp4 = tmp2 + tmp3
    tmp5 = tmp4.to(tl.float32)
    tmp6 = tl.broadcast_to(tmp5, [XBLOCK, R0_BLOCK])
    tmp8 = tl.where(r0_mask & xmask, tmp6, 0)
    tmp9 = tl.broadcast_to(tmp6, [XBLOCK, R0_BLOCK])
    tmp11 = tl.where(r0_mask & xmask, tmp9, 0)
    tmp12 = tl.sum(tmp11, 1)[:, None].to(tl.float32)
    tmp13 = (tl.full([1, 1], 768, tl.int32)).to(tl.float32)
    tmp14 = (tmp12 / tmp13)
    tmp15 = tmp6 - tmp14
    tmp16 = tmp15 * tmp15
    tmp17 = tl.broadcast_to(tmp16, [XBLOCK, R0_BLOCK])
    tmp19 = tl.where(r0_mask & xmask, tmp17, 0)
    tmp20 = tl.sum(tmp19, 1)[:, None].to(tl.float32)
    tmp21 = tmp5 - tmp14
    tmp22 = tl.full([1, 1], 768.0, tl.float32)
    tmp23 = (tmp20 / tmp22)
    tmp24 = tl.full([1, 1], 1e-05, tl.float32)
    tmp25 = tmp23 + tmp24
    tmp26 = libdevice.rsqrt(tmp25)
    tmp27 = tmp21 * tmp26
    tmp29 = tmp28.to(tl.float32)
    tmp30 = tmp27 * tmp29
    tmp32 = tmp31.to(tl.float32)
    tmp33 = tmp30 + tmp32
    tmp34 = tmp33.to(tl.float32)
    tl.store(in_out_ptr0 + (r0_1 + 768*x0), tmp34, r0_mask & xmask)
''', device_str='cuda')

async_compile.wait(globals())
del async_compile

import triton
import triton.language as tl
from torch._inductor.runtime.triton_heuristics import start_graph, end_graph
from torch._C import _cuda_getCurrentRawStream as get_raw_stream
with torch.cuda._DeviceGuard(0):
    raw_stream0 = get_raw_stream(0)
raw_stream0 = get_raw_stream(0)
arg4_1 = generate_example_value((2048, 768), (768, 1), 'cuda:0', torch.float16, 0, (2048, 768))
buf0 = generate_example_value((2048, 768), (768, 1), 'cuda:0', torch.float16, 0, (2048, 768))
arg5_1 = generate_example_value((768,), (1,), 'cuda:0', torch.float16, 0, (768,))
arg6_1 = generate_example_value((768,), (1,), 'cuda:0', torch.float16, 0, (768,))
buf4 = generate_example_value((2048, 768), (768, 1), 'cuda:0', torch.float16, 0, (2048, 768))
with torch.cuda._DeviceGuard(0):
    triton_per_fused_add_native_layer_norm_0.run(arg4_1, buf0, arg5_1, arg6_1, buf4, 2048, 768, stream=raw_stream0)
del buf0, arg5_1, arg6_1, buf4

raw_stream0 = get_raw_stream(0)
buf6 = generate_example_value((2048, 3072), (3072, 1), 'cuda:0', torch.float16, 0, (2048, 3072))
with torch.cuda._DeviceGuard(0):
    triton_poi_fused_relu_1.run(buf6, 6291456, stream=raw_stream0)
del buf6

raw_stream0 = get_raw_stream(0)
buf11 = generate_example_value((2048, 768), (768, 1), 'cuda:0', torch.float16, 0, (2048, 768))
buf7 = generate_example_value((2048, 768), (768, 1), 'cuda:0', torch.float16, 0, (2048, 768))
arg11_1 = generate_example_value((768,), (1,), 'cuda:0', torch.float16, 0, (768,))
arg12_1 = generate_example_value((768,), (1,), 'cuda:0', torch.float16, 0, (768,))
with torch.cuda._DeviceGuard(0):
    triton_per_fused_add_native_layer_norm_2.run(buf11, arg4_1, buf7, arg11_1, arg12_1, 2048, 768, stream=raw_stream0)
del arg4_1, buf11, buf7, arg11_1, arg12_1

"""
# AOT ID: ['12_inference']
from ctypes import c_void_p, c_long, c_int
import torch
import math
import random
import os
import tempfile
from math import inf, nan
from cmath import nanj
from torch._inductor.hooks import run_intermediate_hooks
from torch._inductor.utils import maybe_profile
from torch._inductor.codegen.memory_planning import _align as align
from torch import device, empty_strided
from torch._inductor.async_compile import AsyncCompile
from torch._inductor.select_algorithm import extern_kernels
from torch._C._dynamo.guards import copy_if_misaligned
import triton
import triton.language as tl
from torch._inductor.runtime.triton_heuristics import start_graph, end_graph
from torch._C import _cuda_getCurrentRawStream as get_raw_stream

aten = torch.ops.aten
inductor_ops = torch.ops.inductor
_quantized = torch.ops._quantized
assert_size_stride = torch._C._dynamo.guards.assert_size_stride
assert_alignment = torch._C._dynamo.guards.assert_alignment
empty_strided_cpu = torch._C._dynamo.guards._empty_strided_cpu
empty_strided_cpu_pinned = torch._C._dynamo.guards._empty_strided_cpu_pinned
empty_strided_cuda = torch._C._dynamo.guards._empty_strided_cuda
empty_strided_xpu = torch._C._dynamo.guards._empty_strided_xpu
empty_strided_mtia = torch._C._dynamo.guards._empty_strided_mtia
reinterpret_tensor = torch._C._dynamo.guards._reinterpret_tensor
alloc_from_pool = torch.ops.inductor._alloc_from_pool
async_compile = AsyncCompile()
empty_strided_p2p = torch._C._distributed_c10d._SymmetricMemory.empty_strided_p2p


# kernel path: /tmp/vllm/torch_compile_cache/torch_aot_compile/a9abc970d7110a0f12ab2a3b78291046a3d34468864aa5fea9dc43aff6f67809/inductor_cache/sk/csk7hx3auy7nyiiin6wipd6q55gktiuvenlqghfqrhz7v54q6eq3.py
# Topologically Sorted Source Nodes: [add, layer_norm], Original ATen: [aten.add, aten.native_layer_norm]
# Source node to ATen node mapping:
#   add => add_6
#   layer_norm => add_10, add_11, convert_element_type_3, convert_element_type_4, mul_8, mul_9, rsqrt, sub_3, var_mean
# Graph fragment:
#   %arg4_1 : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=arg4_1]
#   %addmm : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=addmm]
#   %getitem_1 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=getitem_1]
#   %buf2 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=buf2]
#   %arg5_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg5_1]
#   %arg6_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg6_1]
#   %add_6 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.aten.add.Tensor](args = (%arg4_1, %addmm), kwargs = {})
#   %convert_element_type_3 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_6, torch.float32), kwargs = {})
#   %var_mean : [num_users=2] = call_function[target=torch.ops.aten.var_mean.correction](args = (%convert_element_type_3, [1]), kwargs = {correction: 0, keepdim: True})
#   %sub_3 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.sub.Tensor](args = (%convert_element_type_3, %getitem_1), kwargs = {})
#   %add_10 : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%getitem, 1e-05), kwargs = {})
#   %rsqrt : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.rsqrt.default](args = (%add_10,), kwargs = {})
#   %mul_8 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%sub_3, %rsqrt), kwargs = {})
#   %mul_9 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%mul_8, %arg5_1), kwargs = {})
#   %add_11 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%mul_9, %arg6_1), kwargs = {})
#   %convert_element_type_4 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_11, torch.float16), kwargs = {})
#   return %getitem_1,%buf2,%convert_element_type_4
triton_per_fused_add_native_layer_norm_0 = async_compile.triton('triton_per_fused_add_native_layer_norm_0', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.persistent_reduction(
    size_hints={'x': 2048, 'r0_': 1024},
    reduction_hint=ReductionHint.INNER,
    filename=__file__,
    triton_meta={'signature': {'in_ptr0': '*fp16', 'in_ptr1': '*fp16', 'in_ptr2': '*fp16', 'in_ptr3': '*fp16', 'out_ptr2': '*fp16', 'xnumel': 'i32', 'r0_numel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=142, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]], (2,): [['tt.divisibility', 16]], (3,): [['tt.divisibility', 16]], (4,): [['tt.divisibility', 16]], (6,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_per_fused_add_native_layer_norm_0', 'mutated_arg_names': [], 'optimize_mem': True, 'no_x_dim': None, 'atomic_add_found': False, 'num_load': 4, 'num_store': 1, 'num_reduction': 4, 'autotune_hints': set(), 'tiling_scores': {'x': 0, 'r0_': 12585984}, 'kernel_num_gb': 0.009440256, 'kernel_flop': 0, 'backend_hash': 'B2C00AD225F1945839503C666727F7E33E52219DAB5FB3E9C1893C177F82CD58', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False}
)
@triton.jit
def triton_per_fused_add_native_layer_norm_0(in_ptr0, in_ptr1, in_ptr2, in_ptr3, out_ptr2, xnumel, r0_numel, XBLOCK : tl.constexpr):
    r0_numel = 768
    R0_BLOCK: tl.constexpr = 1024
    rnumel = r0_numel
    RBLOCK: tl.constexpr = R0_BLOCK
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:, None]
    xmask = xindex < xnumel
    r0_index = tl.arange(0, R0_BLOCK)[None, :]
    r0_offset = 0
    r0_mask = r0_index < r0_numel
    roffset = r0_offset
    rindex = r0_index
    r0_1 = r0_index
    x0 = xindex
    tmp0 = tl.load(in_ptr0 + (r0_1 + 768*x0), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp1 = tl.load(in_ptr1 + (r0_1 + 768*x0), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp26 = tl.load(in_ptr2 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp29 = tl.load(in_ptr3 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp2 = tmp0 + tmp1
    tmp3 = tmp2.to(tl.float32)
    tmp4 = tl.broadcast_to(tmp3, [XBLOCK, R0_BLOCK])
    tmp6 = tl.where(r0_mask & xmask, tmp4, 0)
    tmp7 = tl.broadcast_to(tmp4, [XBLOCK, R0_BLOCK])
    tmp9 = tl.where(r0_mask & xmask, tmp7, 0)
    tmp10 = tl.sum(tmp9, 1)[:, None].to(tl.float32)
    tmp11 = (tl.full([1, 1], 768, tl.int32)).to(tl.float32)
    tmp12 = (tmp10 / tmp11)
    tmp13 = tmp4 - tmp12
    tmp14 = tmp13 * tmp13
    tmp15 = tl.broadcast_to(tmp14, [XBLOCK, R0_BLOCK])
    tmp17 = tl.where(r0_mask & xmask, tmp15, 0)
    tmp18 = tl.sum(tmp17, 1)[:, None].to(tl.float32)
    tmp19 = tmp3 - tmp12
    tmp20 = tl.full([1, 1], 768.0, tl.float32)
    tmp21 = (tmp18 / tmp20)
    tmp22 = tl.full([1, 1], 1e-05, tl.float32)
    tmp23 = tmp21 + tmp22
    tmp24 = libdevice.rsqrt(tmp23)
    tmp25 = tmp19 * tmp24
    tmp27 = tmp26.to(tl.float32)
    tmp28 = tmp25 * tmp27
    tmp30 = tmp29.to(tl.float32)
    tmp31 = tmp28 + tmp30
    tmp32 = tmp31.to(tl.float32)
    tl.store(out_ptr2 + (r0_1 + 768*x0), tmp32, r0_mask & xmask)
''', device_str='cuda')


# kernel path: /tmp/vllm/torch_compile_cache/torch_aot_compile/a9abc970d7110a0f12ab2a3b78291046a3d34468864aa5fea9dc43aff6f67809/inductor_cache/3k/c3kwmthm7mm6loqkfvah7pf5boslbb73za6zm3bm6vqsxr54ydpj.py
# Topologically Sorted Source Nodes: [relu], Original ATen: [aten.relu]
# Source node to ATen node mapping:
#   relu => relu
# Graph fragment:
#   %addmm_1 : Tensor "f16[s72, 3072][3072, 1]cuda:0" = PlaceHolder[target=addmm_1]
#   %relu : Tensor "f16[s72, 3072][3072, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.relu.default](args = (%addmm_1,), kwargs = {})
#   return %relu
triton_poi_fused_relu_1 = async_compile.triton('triton_poi_fused_relu_1', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.pointwise(
    size_hints={'x': 8388608}, 
    filename=__file__,
    triton_meta={'signature': {'in_out_ptr0': '*fp16', 'xnumel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=142, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_poi_fused_relu_1', 'mutated_arg_names': ['in_out_ptr0'], 'optimize_mem': True, 'no_x_dim': False, 'atomic_add_found': False, 'num_load': 1, 'num_store': 1, 'num_reduction': 0, 'autotune_hints': set(), 'tiling_scores': {'x': 37748736}, 'kernel_num_gb': 0.025165824, 'kernel_flop': 0, 'backend_hash': 'B2C00AD225F1945839503C666727F7E33E52219DAB5FB3E9C1893C177F82CD58', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False},
    min_elem_per_thread=0
)
@triton.jit
def triton_poi_fused_relu_1(in_out_ptr0, xnumel, XBLOCK : tl.constexpr):
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:]
    xmask = xindex < xnumel
    x0 = xindex
    tmp0 = tl.load(in_out_ptr0 + (x0), xmask).to(tl.float32)
    tmp1 = tl.full([1], 0, tl.int32)
    tmp2 = triton_helpers.maximum(tmp1, tmp0)
    tl.store(in_out_ptr0 + (x0), tmp2, xmask)
''', device_str='cuda')


# kernel path: /tmp/vllm/torch_compile_cache/torch_aot_compile/a9abc970d7110a0f12ab2a3b78291046a3d34468864aa5fea9dc43aff6f67809/inductor_cache/jv/cjvhk3kzhrdgyyoztjvvm3m7n4ixjmafyqrqwaogliihzeut7pmd.py
# Topologically Sorted Source Nodes: [add, add_1, layer_norm_1], Original ATen: [aten.add, aten.native_layer_norm]
# Source node to ATen node mapping:
#   add => add_6
#   add_1 => add_30
#   layer_norm_1 => add_34, add_35, convert_element_type_11, convert_element_type_12, mul_24, mul_25, rsqrt_1, sub_11, var_mean_1
# Graph fragment:
#   %arg4_1 : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=arg4_1]
#   %addmm : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=addmm]
#   %addmm_2 : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=addmm_2]
#   %getitem_3 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=getitem_3]
#   %buf9 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=buf9]
#   %arg11_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg11_1]
#   %arg12_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg12_1]
#   %add_6 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.aten.add.Tensor](args = (%arg4_1, %addmm), kwargs = {})
#   %add_30 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%add_6, %addmm_2), kwargs = {})
#   %convert_element_type_11 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_30, torch.float32), kwargs = {})
#   %var_mean_1 : [num_users=2] = call_function[target=torch.ops.aten.var_mean.correction](args = (%convert_element_type_11, [1]), kwargs = {correction: 0, keepdim: True})
#   %sub_11 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.sub.Tensor](args = (%convert_element_type_11, %getitem_3), kwargs = {})
#   %add_34 : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%getitem_2, 1e-05), kwargs = {})
#   %rsqrt_1 : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.rsqrt.default](args = (%add_34,), kwargs = {})
#   %mul_24 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%sub_11, %rsqrt_1), kwargs = {})
#   %mul_25 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%mul_24, %arg11_1), kwargs = {})
#   %add_35 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%mul_25, %arg12_1), kwargs = {})
#   %convert_element_type_12 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_35, torch.float16), kwargs = {})
#   return %getitem_3,%buf9,%convert_element_type_12
triton_per_fused_add_native_layer_norm_2 = async_compile.triton('triton_per_fused_add_native_layer_norm_2', '''
import triton
import triton.language as tl

from torch._inductor.runtime import triton_helpers, triton_heuristics
from torch._inductor.runtime.triton_helpers import libdevice, math as tl_math
from torch._inductor.runtime.hints import AutotuneHint, ReductionHint, TileHint, DeviceProperties
triton_helpers.set_driver_to_gpu()

@triton_heuristics.persistent_reduction(
    size_hints={'x': 2048, 'r0_': 1024},
    reduction_hint=ReductionHint.INNER,
    filename=__file__,
    triton_meta={'signature': {'in_out_ptr0': '*fp16', 'in_ptr0': '*fp16', 'in_ptr1': '*fp16', 'in_ptr2': '*fp16', 'in_ptr3': '*fp16', 'xnumel': 'i32', 'r0_numel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=142, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]], (2,): [['tt.divisibility', 16]], (3,): [['tt.divisibility', 16]], (4,): [['tt.divisibility', 16]], (6,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_per_fused_add_native_layer_norm_2', 'mutated_arg_names': ['in_out_ptr0'], 'optimize_mem': True, 'no_x_dim': None, 'atomic_add_found': False, 'num_load': 5, 'num_store': 1, 'num_reduction': 4, 'autotune_hints': set(), 'tiling_scores': {'x': 0, 'r0_': 15731712}, 'kernel_num_gb': 0.012585984, 'kernel_flop': 0, 'backend_hash': 'B2C00AD225F1945839503C666727F7E33E52219DAB5FB3E9C1893C177F82CD58', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False}
)
@triton.jit
def triton_per_fused_add_native_layer_norm_2(in_out_ptr0, in_ptr0, in_ptr1, in_ptr2, in_ptr3, xnumel, r0_numel, XBLOCK : tl.constexpr):
    r0_numel = 768
    R0_BLOCK: tl.constexpr = 1024
    rnumel = r0_numel
    RBLOCK: tl.constexpr = R0_BLOCK
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:, None]
    xmask = xindex < xnumel
    r0_index = tl.arange(0, R0_BLOCK)[None, :]
    r0_offset = 0
    r0_mask = r0_index < r0_numel
    roffset = r0_offset
    rindex = r0_index
    r0_1 = r0_index
    x0 = xindex
    tmp0 = tl.load(in_ptr0 + (r0_1 + 768*x0), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp1 = tl.load(in_out_ptr0 + (r0_1 + 768*x0), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp3 = tl.load(in_ptr1 + (r0_1 + 768*x0), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp28 = tl.load(in_ptr2 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp31 = tl.load(in_ptr3 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp2 = tmp0 + tmp1
    tmp4 = tmp2 + tmp3
    tmp5 = tmp4.to(tl.float32)
    tmp6 = tl.broadcast_to(tmp5, [XBLOCK, R0_BLOCK])
    tmp8 = tl.where(r0_mask & xmask, tmp6, 0)
    tmp9 = tl.broadcast_to(tmp6, [XBLOCK, R0_BLOCK])
    tmp11 = tl.where(r0_mask & xmask, tmp9, 0)
    tmp12 = tl.sum(tmp11, 1)[:, None].to(tl.float32)
    tmp13 = (tl.full([1, 1], 768, tl.int32)).to(tl.float32)
    tmp14 = (tmp12 / tmp13)
    tmp15 = tmp6 - tmp14
    tmp16 = tmp15 * tmp15
    tmp17 = tl.broadcast_to(tmp16, [XBLOCK, R0_BLOCK])
    tmp19 = tl.where(r0_mask & xmask, tmp17, 0)
    tmp20 = tl.sum(tmp19, 1)[:, None].to(tl.float32)
    tmp21 = tmp5 - tmp14
    tmp22 = tl.full([1, 1], 768.0, tl.float32)
    tmp23 = (tmp20 / tmp22)
    tmp24 = tl.full([1, 1], 1e-05, tl.float32)
    tmp25 = tmp23 + tmp24
    tmp26 = libdevice.rsqrt(tmp25)
    tmp27 = tmp21 * tmp26
    tmp29 = tmp28.to(tl.float32)
    tmp30 = tmp27 * tmp29
    tmp32 = tmp31.to(tl.float32)
    tmp33 = tmp30 + tmp32
    tmp34 = tmp33.to(tl.float32)
    tl.store(in_out_ptr0 + (r0_1 + 768*x0), tmp34, r0_mask & xmask)
''', device_str='cuda')


async_compile.wait(globals())
del async_compile

class Runner:
    def __init__(self, partitions):
        self.partitions = partitions

    def recursively_apply_fns(self, fns):
        new_callables = []
        for fn, c in zip(fns, self.partitions):
            new_callables.append(fn(c))
        self.partitions = new_callables

    def call(self, args):
        arg0_1, arg1_1, arg2_1, arg3_1, arg4_1, arg5_1, arg6_1, arg7_1, arg8_1, arg9_1, arg10_1, arg11_1, arg12_1 = args
        args.clear()
        s72 = arg1_1
        s80 = s72
        assert_size_stride(arg3_1, (768, ), (1, ), 'input')
        assert_size_stride(arg0_1, (s72, 12, 64), (768, 64, 1), 'input')
        assert_size_stride(arg2_1, (768, 768), (768, 1), 'input')
        with torch.cuda._DeviceGuard(0):
            torch.cuda.set_device(0)
            arg3_1 = copy_if_misaligned(arg3_1)
            arg0_1 = copy_if_misaligned(arg0_1)
            arg2_1 = copy_if_misaligned(arg2_1)
            buf0 = empty_strided_cuda((s72, 768), (768, 1), torch.float16)
            # Topologically Sorted Source Nodes: [view, linear], Original ATen: [aten.view, aten.t, aten.addmm]
            extern_kernels.addmm(arg3_1, reinterpret_tensor(arg0_1, (s72, 768), (768, 1), 0), reinterpret_tensor(arg2_1, (768, 768), (1, 768), 0), alpha=1, beta=1, out=buf0)
            del arg0_1
            del arg2_1
            del arg3_1
            assert_size_stride(arg4_1, (s72, 768), (768, 1), 'input')
            assert_size_stride(arg5_1, (768, ), (1, ), 'input')
            assert_size_stride(arg6_1, (768, ), (1, ), 'input')
            arg4_1 = copy_if_misaligned(arg4_1)
            arg5_1 = copy_if_misaligned(arg5_1)
            arg6_1 = copy_if_misaligned(arg6_1)
            buf4 = empty_strided_cuda((s72, 768), (768, 1), torch.float16)
            # Topologically Sorted Source Nodes: [add, layer_norm], Original ATen: [aten.add, aten.native_layer_norm]
            raw_stream0 = get_raw_stream(0)
            triton_per_fused_add_native_layer_norm_0.run(arg4_1, buf0, arg5_1, arg6_1, buf4, s72, 768, stream=raw_stream0)
            del arg5_1
            del arg6_1
            assert_size_stride(arg8_1, (3072, ), (1, ), 'input')
            assert_size_stride(arg7_1, (3072, 768), (768, 1), 'input')
            arg8_1 = copy_if_misaligned(arg8_1)
            arg7_1 = copy_if_misaligned(arg7_1)
            buf5 = empty_strided_cuda((s72, 3072), (3072, 1), torch.float16)
            # Topologically Sorted Source Nodes: [add, layer_norm, linear_1], Original ATen: [aten.add, aten.native_layer_norm, aten.t, aten.addmm]
            extern_kernels.addmm(arg8_1, buf4, reinterpret_tensor(arg7_1, (768, 3072), (1, 768), 0), alpha=1, beta=1, out=buf5)
            del arg7_1
            del arg8_1
            del buf4
            buf6 = buf5; del buf5  # reuse
            # Topologically Sorted Source Nodes: [relu], Original ATen: [aten.relu]
            triton_poi_fused_relu_1_xnumel = 3072*s72
            raw_stream0 = get_raw_stream(0)
            triton_poi_fused_relu_1.run(buf6, triton_poi_fused_relu_1_xnumel, stream=raw_stream0)
            assert_size_stride(arg10_1, (768, ), (1, ), 'input')
            assert_size_stride(arg9_1, (768, 3072), (3072, 1), 'input')
            arg10_1 = copy_if_misaligned(arg10_1)
            arg9_1 = copy_if_misaligned(arg9_1)
            buf7 = empty_strided_cuda((s72, 768), (768, 1), torch.float16)
            # Topologically Sorted Source Nodes: [relu, linear_2], Original ATen: [aten.relu, aten.t, aten.addmm]
            extern_kernels.addmm(arg10_1, buf6, reinterpret_tensor(arg9_1, (3072, 768), (1, 3072), 0), alpha=1, beta=1, out=buf7)
            del arg10_1
            del arg9_1
            del buf6
            assert_size_stride(arg11_1, (768, ), (1, ), 'input')
            assert_size_stride(arg12_1, (768, ), (1, ), 'input')
            arg11_1 = copy_if_misaligned(arg11_1)
            arg12_1 = copy_if_misaligned(arg12_1)
            buf11 = buf0; del buf0  # reuse
            # Topologically Sorted Source Nodes: [add, add_1, layer_norm_1], Original ATen: [aten.add, aten.native_layer_norm]
            raw_stream0 = get_raw_stream(0)
            triton_per_fused_add_native_layer_norm_2.run(buf11, arg4_1, buf7, arg11_1, arg12_1, s72, 768, stream=raw_stream0)
            del arg11_1
            del arg12_1
            del arg4_1
            del buf7
        return (buf11, )

runner = Runner(partitions=[])
call = runner.call
recursively_apply_fns = runner.recursively_apply_fns


def get_args():
    from torch._dynamo.testing import rand_strided
    arg0_1 = rand_strided((2048, 12, 64), (768, 64, 1), device='cuda:0', dtype=torch.float16)
    arg1_1 = 2048
    arg2_1 = rand_strided((768, 768), (768, 1), device='cuda:0', dtype=torch.float16)
    arg3_1 = rand_strided((768, ), (1, ), device='cuda:0', dtype=torch.float16)
    arg4_1 = rand_strided((2048, 768), (768, 1), device='cuda:0', dtype=torch.float16)
    arg5_1 = rand_strided((768, ), (1, ), device='cuda:0', dtype=torch.float16)
    arg6_1 = rand_strided((768, ), (1, ), device='cuda:0', dtype=torch.float16)
    arg7_1 = rand_strided((3072, 768), (768, 1), device='cuda:0', dtype=torch.float16)
    arg8_1 = rand_strided((3072, ), (1, ), device='cuda:0', dtype=torch.float16)
    arg9_1 = rand_strided((768, 3072), (3072, 1), device='cuda:0', dtype=torch.float16)
    arg10_1 = rand_strided((768, ), (1, ), device='cuda:0', dtype=torch.float16)
    arg11_1 = rand_strided((768, ), (1, ), device='cuda:0', dtype=torch.float16)
    arg12_1 = rand_strided((768, ), (1, ), device='cuda:0', dtype=torch.float16)
    return [arg0_1, arg1_1, arg2_1, arg3_1, arg4_1, arg5_1, arg6_1, arg7_1, arg8_1, arg9_1, arg10_1, arg11_1, arg12_1]


def benchmark_compiled_module(args, times=10, repeat=10):
    from torch._inductor.utils import print_performance
    fn = lambda: call(list(args))
    return print_performance(fn, times=times, repeat=repeat, device='cuda')


if __name__ == "__main__":
    from torch._inductor.wrapper_benchmark import compiled_module_main
    args = get_args()
    compiled_module_main('None', lambda times, repeat: benchmark_compiled_module(args, times=times, repeat=repeat))
