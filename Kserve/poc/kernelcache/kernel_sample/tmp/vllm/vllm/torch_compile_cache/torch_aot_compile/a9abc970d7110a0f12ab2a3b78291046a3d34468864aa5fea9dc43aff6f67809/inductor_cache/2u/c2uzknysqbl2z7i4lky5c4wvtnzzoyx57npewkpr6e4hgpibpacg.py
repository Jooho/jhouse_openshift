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


# kernel path: /tmp/vllm/torch_compile_cache/torch_aot_compile/a9abc970d7110a0f12ab2a3b78291046a3d34468864aa5fea9dc43aff6f67809/inductor_cache/bi/cbiworrtbdjxwdlvt3rjlcxzryzp4r6sxcahgqfdqbjq6zjyvtod.py
# Topologically Sorted Source Nodes: [long, embedding, add, embedding_1, add_1, layer_norm], Original ATen: [aten._to_copy, aten.embedding, aten.add, aten.native_layer_norm]
# Source node to ATen node mapping:
#   add => add_5
#   add_1 => add_11
#   embedding => embedding
#   embedding_1 => embedding_1
#   layer_norm => add_15, add_16, convert_element_type_1, convert_element_type_2, mul_10, mul_11, rsqrt, sub_5, var_mean
#   long => convert_element_type
# Graph fragment:
#   %arg0_1 : Tensor "i32[s72][1]cuda:0" = PlaceHolder[target=arg0_1]
#   %arg2_1 : Tensor "f16[50304, 768][768, 1]cuda:0" = PlaceHolder[target=arg2_1]
#   %arg3_1 : Tensor "i64[s72][1]cuda:0" = PlaceHolder[target=arg3_1]
#   %arg4_1 : Tensor "f16[2050, 768][768, 1]cuda:0" = PlaceHolder[target=arg4_1]
#   %add_11 : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=add_11]
#   %getitem_1 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=getitem_1]
#   %buf2 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=buf2]
#   %arg5_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg5_1]
#   %arg6_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg6_1]
#   %convert_element_type : Tensor "i64[s72][1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%arg0_1, torch.int64), kwargs = {})
#   %embedding : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.embedding.default](args = (%arg2_1, %convert_element_type), kwargs = {})
#   %add_5 : Tensor "i64[s72][1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%arg3_1, 2), kwargs = {})
#   %embedding_1 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.embedding.default](args = (%arg4_1, %add_5), kwargs = {})
#   %add_11 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.aten.add.Tensor](args = (%embedding, %embedding_1), kwargs = {})
#   %convert_element_type_1 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_11, torch.float32), kwargs = {})
#   %var_mean : [num_users=2] = call_function[target=torch.ops.aten.var_mean.correction](args = (%convert_element_type_1, [1]), kwargs = {correction: 0, keepdim: True})
#   %sub_5 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.sub.Tensor](args = (%convert_element_type_1, %getitem_1), kwargs = {})
#   %add_15 : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%getitem, 1e-05), kwargs = {})
#   %rsqrt : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.rsqrt.default](args = (%add_15,), kwargs = {})
#   %mul_10 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%sub_5, %rsqrt), kwargs = {})
#   %mul_11 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%mul_10, %arg5_1), kwargs = {})
#   %add_16 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%mul_11, %arg6_1), kwargs = {})
#   %convert_element_type_2 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_16, torch.float16), kwargs = {})
#   return %add_11,%getitem_1,%buf2,%convert_element_type_2
triton_per_fused__to_copy_add_embedding_native_layer_norm_0 = async_compile.triton('triton_per_fused__to_copy_add_embedding_native_layer_norm_0', '''
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
    triton_meta={'signature': {'in_ptr0': '*i32', 'in_ptr1': '*fp16', 'in_ptr2': '*i64', 'in_ptr3': '*fp16', 'in_ptr4': '*fp16', 'in_ptr5': '*fp16', 'out_ptr0': '*fp16', 'out_ptr3': '*fp16', 'xnumel': 'i32', 'r0_numel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=142, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]], (2,): [['tt.divisibility', 16]], (3,): [['tt.divisibility', 16]], (4,): [['tt.divisibility', 16]], (5,): [['tt.divisibility', 16]], (6,): [['tt.divisibility', 16]], (7,): [['tt.divisibility', 16]], (9,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_per_fused__to_copy_add_embedding_native_layer_norm_0', 'mutated_arg_names': [], 'optimize_mem': True, 'no_x_dim': None, 'atomic_add_found': False, 'num_load': 4, 'num_store': 2, 'num_reduction': 4, 'autotune_hints': set(), 'tiling_scores': {'x': 24576, 'r0_': 12585984}, 'kernel_num_gb': 0.01261056, 'kernel_flop': 0, 'backend_hash': 'B2C00AD225F1945839503C666727F7E33E52219DAB5FB3E9C1893C177F82CD58', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False}
)
@triton.jit
def triton_per_fused__to_copy_add_embedding_native_layer_norm_0(in_ptr0, in_ptr1, in_ptr2, in_ptr3, in_ptr4, in_ptr5, out_ptr0, out_ptr3, xnumel, r0_numel, XBLOCK : tl.constexpr):
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
    x0 = xindex
    r0_1 = r0_index
    tmp0 = tl.load(in_ptr0 + (x0), xmask, eviction_policy='evict_last')
    tmp4 = tl.load(in_ptr2 + (x0), xmask, eviction_policy='evict_last')
    tmp33 = tl.load(in_ptr4 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp36 = tl.load(in_ptr5 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp1 = tmp0.to(tl.int64)
    tl.device_assert(((0 <= tmp1) & (tmp1 < 50304)) | ~(xmask), "index out of bounds: 0 <= tmp1 < 50304")
    tmp3 = tl.load(in_ptr1 + (r0_1 + 768*tmp1), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp5 = tl.full([1, 1], 2, tl.int64)
    tmp6 = tmp4 + tmp5
    tl.device_assert(((0 <= tmp6) & (tmp6 < 2050)) | ~(xmask), "index out of bounds: 0 <= tmp6 < 2050")
    tmp8 = tl.load(in_ptr3 + (r0_1 + 768*tmp6), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp9 = tmp3 + tmp8
    tmp10 = tmp9.to(tl.float32)
    tmp11 = tl.broadcast_to(tmp10, [XBLOCK, R0_BLOCK])
    tmp13 = tl.where(r0_mask & xmask, tmp11, 0)
    tmp14 = tl.broadcast_to(tmp11, [XBLOCK, R0_BLOCK])
    tmp16 = tl.where(r0_mask & xmask, tmp14, 0)
    tmp17 = tl.sum(tmp16, 1)[:, None].to(tl.float32)
    tmp18 = (tl.full([1, 1], 768, tl.int32)).to(tl.float32)
    tmp19 = (tmp17 / tmp18)
    tmp20 = tmp11 - tmp19
    tmp21 = tmp20 * tmp20
    tmp22 = tl.broadcast_to(tmp21, [XBLOCK, R0_BLOCK])
    tmp24 = tl.where(r0_mask & xmask, tmp22, 0)
    tmp25 = tl.sum(tmp24, 1)[:, None].to(tl.float32)
    tmp26 = tmp10 - tmp19
    tmp27 = tl.full([1, 1], 768.0, tl.float32)
    tmp28 = (tmp25 / tmp27)
    tmp29 = tl.full([1, 1], 1e-05, tl.float32)
    tmp30 = tmp28 + tmp29
    tmp31 = libdevice.rsqrt(tmp30)
    tmp32 = tmp26 * tmp31
    tmp34 = tmp33.to(tl.float32)
    tmp35 = tmp32 * tmp34
    tmp37 = tmp36.to(tl.float32)
    tmp38 = tmp35 + tmp37
    tmp39 = tmp38.to(tl.float32)
    tl.store(out_ptr0 + (r0_1 + 768*x0), tmp9, r0_mask & xmask)
    tl.store(out_ptr3 + (r0_1 + 768*x0), tmp39, r0_mask & xmask)
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
arg0_1 = generate_example_value((2048,), (1,), 'cuda:0', torch.int32, 0, (2048,))
arg2_1 = generate_example_value((50304, 768), (768, 1), 'cuda:0', torch.float16, 0, (50304, 768))
arg3_1 = generate_example_value((2048,), (1,), 'cuda:0', torch.int64, 0, (2048,))
arg4_1 = generate_example_value((2050, 768), (768, 1), 'cuda:0', torch.float16, 0, (2050, 768))
arg5_1 = generate_example_value((768,), (1,), 'cuda:0', torch.float16, 0, (768,))
arg6_1 = generate_example_value((768,), (1,), 'cuda:0', torch.float16, 0, (768,))
buf0 = generate_example_value((2048, 768), (768, 1), 'cuda:0', torch.float16, 0, (2048, 768))
buf4 = generate_example_value((2048, 768), (768, 1), 'cuda:0', torch.float16, 0, (2048, 768))
with torch.cuda._DeviceGuard(0):
    triton_per_fused__to_copy_add_embedding_native_layer_norm_0.run(arg0_1, arg2_1, arg3_1, arg4_1, arg5_1, arg6_1, buf0, buf4, 2048, 768, stream=raw_stream0)
del arg0_1, arg2_1, arg3_1, arg4_1, arg5_1, arg6_1, buf0, buf4

"""
# AOT ID: ['0_inference']
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


# kernel path: /tmp/vllm/torch_compile_cache/torch_aot_compile/a9abc970d7110a0f12ab2a3b78291046a3d34468864aa5fea9dc43aff6f67809/inductor_cache/bi/cbiworrtbdjxwdlvt3rjlcxzryzp4r6sxcahgqfdqbjq6zjyvtod.py
# Topologically Sorted Source Nodes: [long, embedding, add, embedding_1, add_1, layer_norm], Original ATen: [aten._to_copy, aten.embedding, aten.add, aten.native_layer_norm]
# Source node to ATen node mapping:
#   add => add_5
#   add_1 => add_11
#   embedding => embedding
#   embedding_1 => embedding_1
#   layer_norm => add_15, add_16, convert_element_type_1, convert_element_type_2, mul_10, mul_11, rsqrt, sub_5, var_mean
#   long => convert_element_type
# Graph fragment:
#   %arg0_1 : Tensor "i32[s72][1]cuda:0" = PlaceHolder[target=arg0_1]
#   %arg2_1 : Tensor "f16[50304, 768][768, 1]cuda:0" = PlaceHolder[target=arg2_1]
#   %arg3_1 : Tensor "i64[s72][1]cuda:0" = PlaceHolder[target=arg3_1]
#   %arg4_1 : Tensor "f16[2050, 768][768, 1]cuda:0" = PlaceHolder[target=arg4_1]
#   %add_11 : Tensor "f16[s72, 768][768, 1]cuda:0" = PlaceHolder[target=add_11]
#   %getitem_1 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=getitem_1]
#   %buf2 : Tensor "f32[s72, 1][1, s72]cuda:0" = PlaceHolder[target=buf2]
#   %arg5_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg5_1]
#   %arg6_1 : Tensor "f16[768][1]cuda:0" = PlaceHolder[target=arg6_1]
#   %convert_element_type : Tensor "i64[s72][1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%arg0_1, torch.int64), kwargs = {})
#   %embedding : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.embedding.default](args = (%arg2_1, %convert_element_type), kwargs = {})
#   %add_5 : Tensor "i64[s72][1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%arg3_1, 2), kwargs = {})
#   %embedding_1 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.embedding.default](args = (%arg4_1, %add_5), kwargs = {})
#   %add_11 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.aten.add.Tensor](args = (%embedding, %embedding_1), kwargs = {})
#   %convert_element_type_1 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=2] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_11, torch.float32), kwargs = {})
#   %var_mean : [num_users=2] = call_function[target=torch.ops.aten.var_mean.correction](args = (%convert_element_type_1, [1]), kwargs = {correction: 0, keepdim: True})
#   %sub_5 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.sub.Tensor](args = (%convert_element_type_1, %getitem_1), kwargs = {})
#   %add_15 : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%getitem, 1e-05), kwargs = {})
#   %rsqrt : Tensor "f32[s72, 1][1, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.rsqrt.default](args = (%add_15,), kwargs = {})
#   %mul_10 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%sub_5, %rsqrt), kwargs = {})
#   %mul_11 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.mul.Tensor](args = (%mul_10, %arg5_1), kwargs = {})
#   %add_16 : Tensor "f32[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.aten.add.Tensor](args = (%mul_11, %arg6_1), kwargs = {})
#   %convert_element_type_2 : Tensor "f16[s72, 768][768, 1]cuda:0"[num_users=1] = call_function[target=torch.ops.prims.convert_element_type.default](args = (%add_16, torch.float16), kwargs = {})
#   return %add_11,%getitem_1,%buf2,%convert_element_type_2
triton_per_fused__to_copy_add_embedding_native_layer_norm_0 = async_compile.triton('triton_per_fused__to_copy_add_embedding_native_layer_norm_0', '''
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
    triton_meta={'signature': {'in_ptr0': '*i32', 'in_ptr1': '*fp16', 'in_ptr2': '*i64', 'in_ptr3': '*fp16', 'in_ptr4': '*fp16', 'in_ptr5': '*fp16', 'out_ptr0': '*fp16', 'out_ptr3': '*fp16', 'xnumel': 'i32', 'r0_numel': 'i32', 'XBLOCK': 'constexpr'}, 'device': DeviceProperties(type='cuda', index=0, multi_processor_count=142, cc=89, major=8, regs_per_multiprocessor=65536, max_threads_per_multi_processor=1536, max_threads_per_block=1024, warp_size=32), 'constants': {}, 'native_matmul': False, 'enable_fp_fusion': True, 'launch_pdl': False, 'disable_ftz': False, 'configs': [{(0,): [['tt.divisibility', 16]], (1,): [['tt.divisibility', 16]], (2,): [['tt.divisibility', 16]], (3,): [['tt.divisibility', 16]], (4,): [['tt.divisibility', 16]], (5,): [['tt.divisibility', 16]], (6,): [['tt.divisibility', 16]], (7,): [['tt.divisibility', 16]], (9,): [['tt.divisibility', 16]]}]},
    inductor_meta={'grid_type': 'Grid1D', 'kernel_name': 'triton_per_fused__to_copy_add_embedding_native_layer_norm_0', 'mutated_arg_names': [], 'optimize_mem': True, 'no_x_dim': None, 'atomic_add_found': False, 'num_load': 4, 'num_store': 2, 'num_reduction': 4, 'autotune_hints': set(), 'tiling_scores': {'x': 24576, 'r0_': 12585984}, 'kernel_num_gb': 0.01261056, 'kernel_flop': 0, 'backend_hash': 'B2C00AD225F1945839503C666727F7E33E52219DAB5FB3E9C1893C177F82CD58', 'assert_indirect_indexing': True, 'autotune_local_cache': True, 'autotune_pointwise': True, 'autotune_remote_cache': None, 'force_disable_caches': False, 'dynamic_scale_rblock': True, 'incremental_autotune': False, 'max_autotune': False, 'max_autotune_pointwise': False, 'min_split_scan_rblock': 256, 'spill_threshold': 16, 'store_cubin': False, 'deterministic': False, 'batch_invariant': False, 'force_filter_reduction_configs': False, 'mix_order_reduction_allow_multi_stages': True, 'dynamic_disable_pipelining': True, 'are_deterministic_algorithms_enabled': False}
)
@triton.jit
def triton_per_fused__to_copy_add_embedding_native_layer_norm_0(in_ptr0, in_ptr1, in_ptr2, in_ptr3, in_ptr4, in_ptr5, out_ptr0, out_ptr3, xnumel, r0_numel, XBLOCK : tl.constexpr):
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
    x0 = xindex
    r0_1 = r0_index
    tmp0 = tl.load(in_ptr0 + (x0), xmask, eviction_policy='evict_last')
    tmp4 = tl.load(in_ptr2 + (x0), xmask, eviction_policy='evict_last')
    tmp33 = tl.load(in_ptr4 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp36 = tl.load(in_ptr5 + (r0_1), r0_mask, eviction_policy='evict_last', other=0.0).to(tl.float32)
    tmp1 = tmp0.to(tl.int64)
    tl.device_assert(((0 <= tmp1) & (tmp1 < 50304)) | ~(xmask), "index out of bounds: 0 <= tmp1 < 50304")
    tmp3 = tl.load(in_ptr1 + (r0_1 + 768*tmp1), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp5 = tl.full([1, 1], 2, tl.int64)
    tmp6 = tmp4 + tmp5
    tl.device_assert(((0 <= tmp6) & (tmp6 < 2050)) | ~(xmask), "index out of bounds: 0 <= tmp6 < 2050")
    tmp8 = tl.load(in_ptr3 + (r0_1 + 768*tmp6), r0_mask & xmask, eviction_policy='evict_first', other=0.0).to(tl.float32)
    tmp9 = tmp3 + tmp8
    tmp10 = tmp9.to(tl.float32)
    tmp11 = tl.broadcast_to(tmp10, [XBLOCK, R0_BLOCK])
    tmp13 = tl.where(r0_mask & xmask, tmp11, 0)
    tmp14 = tl.broadcast_to(tmp11, [XBLOCK, R0_BLOCK])
    tmp16 = tl.where(r0_mask & xmask, tmp14, 0)
    tmp17 = tl.sum(tmp16, 1)[:, None].to(tl.float32)
    tmp18 = (tl.full([1, 1], 768, tl.int32)).to(tl.float32)
    tmp19 = (tmp17 / tmp18)
    tmp20 = tmp11 - tmp19
    tmp21 = tmp20 * tmp20
    tmp22 = tl.broadcast_to(tmp21, [XBLOCK, R0_BLOCK])
    tmp24 = tl.where(r0_mask & xmask, tmp22, 0)
    tmp25 = tl.sum(tmp24, 1)[:, None].to(tl.float32)
    tmp26 = tmp10 - tmp19
    tmp27 = tl.full([1, 1], 768.0, tl.float32)
    tmp28 = (tmp25 / tmp27)
    tmp29 = tl.full([1, 1], 1e-05, tl.float32)
    tmp30 = tmp28 + tmp29
    tmp31 = libdevice.rsqrt(tmp30)
    tmp32 = tmp26 * tmp31
    tmp34 = tmp33.to(tl.float32)
    tmp35 = tmp32 * tmp34
    tmp37 = tmp36.to(tl.float32)
    tmp38 = tmp35 + tmp37
    tmp39 = tmp38.to(tl.float32)
    tl.store(out_ptr0 + (r0_1 + 768*x0), tmp9, r0_mask & xmask)
    tl.store(out_ptr3 + (r0_1 + 768*x0), tmp39, r0_mask & xmask)
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
        arg0_1, arg1_1, arg2_1, arg3_1, arg4_1, arg5_1, arg6_1, arg7_1, arg8_1 = args
        args.clear()
        s72 = arg1_1
        s80 = s72
        assert_size_stride(arg0_1, (s72, ), (1, ), 'input')
        assert_size_stride(arg2_1, (50304, 768), (768, 1), 'input')
        assert_size_stride(arg3_1, (s72, ), (1, ), 'input')
        assert_size_stride(arg4_1, (2050, 768), (768, 1), 'input')
        assert_size_stride(arg5_1, (768, ), (1, ), 'input')
        assert_size_stride(arg6_1, (768, ), (1, ), 'input')
        with torch.cuda._DeviceGuard(0):
            torch.cuda.set_device(0)
            arg0_1 = copy_if_misaligned(arg0_1)
            arg2_1 = copy_if_misaligned(arg2_1)
            arg3_1 = copy_if_misaligned(arg3_1)
            arg4_1 = copy_if_misaligned(arg4_1)
            arg5_1 = copy_if_misaligned(arg5_1)
            arg6_1 = copy_if_misaligned(arg6_1)
            buf0 = empty_strided_cuda((s72, 768), (768, 1), torch.float16)
            buf4 = empty_strided_cuda((s72, 768), (768, 1), torch.float16)
            # Topologically Sorted Source Nodes: [long, embedding, add, embedding_1, add_1, layer_norm], Original ATen: [aten._to_copy, aten.embedding, aten.add, aten.native_layer_norm]
            raw_stream0 = get_raw_stream(0)
            triton_per_fused__to_copy_add_embedding_native_layer_norm_0.run(arg0_1, arg2_1, arg3_1, arg4_1, arg5_1, arg6_1, buf0, buf4, s72, 768, stream=raw_stream0)
            del arg0_1
            del arg2_1
            del arg3_1
            del arg4_1
            del arg5_1
            del arg6_1
            assert_size_stride(arg8_1, (2304, ), (1, ), 'input')
            assert_size_stride(arg7_1, (2304, 768), (768, 1), 'input')
            arg8_1 = copy_if_misaligned(arg8_1)
            arg7_1 = copy_if_misaligned(arg7_1)
            buf5 = empty_strided_cuda((s72, 2304), (2304, 1), torch.float16)
            # Topologically Sorted Source Nodes: [layer_norm, linear], Original ATen: [aten.native_layer_norm, aten.t, aten.addmm]
            extern_kernels.addmm(arg8_1, buf4, reinterpret_tensor(arg7_1, (768, 2304), (1, 768), 0), alpha=1, beta=1, out=buf5)
            del arg7_1
            del arg8_1
            buf6 = buf4; del buf4  # reuse
        return (reinterpret_tensor(buf5, (s72, 12, 64), (2304, 64, 1), 768), reinterpret_tensor(buf5, (s72, 12, 64), (2304, 64, 1), 1536), reinterpret_tensor(buf5, (s72, 12, 64), (2304, 64, 1), 0), reinterpret_tensor(buf6, (s72, 12, 64), (768, 64, 1), 0), buf0, )

runner = Runner(partitions=[])
call = runner.call
recursively_apply_fns = runner.recursively_apply_fns


def get_args():
    from torch._dynamo.testing import rand_strided
    arg0_1 = rand_strided((2048, ), (1, ), device='cuda:0', dtype=torch.int32)
    arg1_1 = 2048
    arg2_1 = rand_strided((50304, 768), (768, 1), device='cuda:0', dtype=torch.float16)
    arg3_1 = rand_strided((2048, ), (1, ), device='cuda:0', dtype=torch.int64)
    arg4_1 = rand_strided((2050, 768), (768, 1), device='cuda:0', dtype=torch.float16)
    arg5_1 = rand_strided((768, ), (1, ), device='cuda:0', dtype=torch.float16)
    arg6_1 = rand_strided((768, ), (1, ), device='cuda:0', dtype=torch.float16)
    arg7_1 = rand_strided((2304, 768), (768, 1), device='cuda:0', dtype=torch.float16)
    arg8_1 = rand_strided((2304, ), (1, ), device='cuda:0', dtype=torch.float16)
    return [arg0_1, arg1_1, arg2_1, arg3_1, arg4_1, arg5_1, arg6_1, arg7_1, arg8_1]


def benchmark_compiled_module(args, times=10, repeat=10):
    from torch._inductor.utils import print_performance
    fn = lambda: call(list(args))
    return print_performance(fn, times=times, repeat=repeat, device='cuda')


if __name__ == "__main__":
    from torch._inductor.wrapper_benchmark import compiled_module_main
    args = get_args()
    compiled_module_main('None', lambda times, repeat: benchmark_compiled_module(args, times=times, repeat=repeat))
