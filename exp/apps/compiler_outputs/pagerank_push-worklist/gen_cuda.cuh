#pragma once
#include <cuda.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
#include "gen_cuda.h"
#include "Galois/Runtime/Cuda/cuda_helpers.h"

struct CUDA_Context : public CUDA_Context_Common {
	struct CUDA_Context_Field<unsigned int> nout;
	struct CUDA_Context_Field<float> residual;
	struct CUDA_Context_Field<float> value;
	Worklist2 in_wl;
	Worklist2 out_wl;
	struct CUDA_Worklist *shared_wl;
};

struct CUDA_Context *get_CUDA_context(int id) {
	struct CUDA_Context *ctx;
	ctx = (struct CUDA_Context *) calloc(1, sizeof(struct CUDA_Context));
	ctx->id = id;
	return ctx;
}

bool init_CUDA_context(struct CUDA_Context *ctx, int device) {
	return init_CUDA_context_common(ctx, device);
}

void load_graph_CUDA(struct CUDA_Context *ctx, struct CUDA_Worklist *wl, double wl_dup_factor, MarshalGraph &g, unsigned num_hosts) {
	size_t mem_usage = mem_usage_CUDA_common(g, num_hosts);
	mem_usage += mem_usage_CUDA_field(&ctx->nout, g, num_hosts);
	mem_usage += mem_usage_CUDA_field(&ctx->residual, g, num_hosts);
	mem_usage += mem_usage_CUDA_field(&ctx->value, g, num_hosts);
	printf("[%d] Host memory for communication context: %3u MB\n", ctx->id, mem_usage/1048756);
	load_graph_CUDA_common(ctx, g, num_hosts);
	load_graph_CUDA_field(ctx, &ctx->nout, num_hosts);
	load_graph_CUDA_field(ctx, &ctx->residual, num_hosts);
	load_graph_CUDA_field(ctx, &ctx->value, num_hosts);
	wl->max_size = wl_dup_factor*g.nnodes;
	ctx->in_wl = Worklist2((size_t)wl->max_size);
	ctx->out_wl = Worklist2((size_t)wl->max_size);
	wl->num_in_items = -1;
	wl->num_out_items = -1;
	wl->in_items = ctx->in_wl.wl;
	wl->out_items = ctx->out_wl.wl;
	ctx->shared_wl = wl;
	printf("[%d] load_graph_GPU: worklist size %d\n", ctx->id, (size_t)wl_dup_factor*g.nnodes);
	reset_CUDA_context(ctx);
}

void reset_CUDA_context(struct CUDA_Context *ctx) {
	ctx->nout.data.zero_gpu();
	ctx->residual.data.zero_gpu();
	ctx->value.data.zero_gpu();
}

void bitset_nout_clear_cuda(struct CUDA_Context *ctx) {
	ctx->nout.is_updated.cpu_rd_ptr()->reset_all();
}

unsigned int get_node_nout_cuda(struct CUDA_Context *ctx, unsigned LID) {
	unsigned int *nout = ctx->nout.data.cpu_rd_ptr();
	return nout[LID];
}

void set_node_nout_cuda(struct CUDA_Context *ctx, unsigned LID, unsigned int v) {
	unsigned int *nout = ctx->nout.data.cpu_wr_ptr();
	nout[LID] = v;
}

void add_node_nout_cuda(struct CUDA_Context *ctx, unsigned LID, unsigned int v) {
	unsigned int *nout = ctx->nout.data.cpu_wr_ptr();
	nout[LID] += v;
}

void min_node_nout_cuda(struct CUDA_Context *ctx, unsigned LID, unsigned int v) {
	unsigned int *nout = ctx->nout.data.cpu_wr_ptr();
	if (nout[LID] > v)
		nout[LID] = v;
}

void batch_get_node_nout_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned int *v) {
	batch_get_shared_field<unsigned int, sharedMaster, false>(ctx, &ctx->nout, from_id, v);
}

void batch_get_node_nout_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, unsigned int *v, size_t *v_size, DataCommMode *data_mode) {
	batch_get_shared_field<unsigned int, sharedMaster, false>(ctx, &ctx->nout, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_get_mirror_node_nout_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned int *v) {
	batch_get_shared_field<unsigned int, sharedMirror, false>(ctx, &ctx->nout, from_id, v);
}

void batch_get_mirror_node_nout_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, unsigned int *v, size_t *v_size, DataCommMode *data_mode) {
	batch_get_shared_field<unsigned int, sharedMirror, false>(ctx, &ctx->nout, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_get_reset_node_nout_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned int *v, unsigned int i) {
	batch_get_shared_field<unsigned int, sharedMirror, true>(ctx, &ctx->nout, from_id, v, i);
}

void batch_get_reset_node_nout_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, unsigned int *v, size_t *v_size, DataCommMode *data_mode, unsigned int i) {
	batch_get_shared_field<unsigned int, sharedMirror, true>(ctx, &ctx->nout, from_id, bitset_comm, offsets, v, v_size, data_mode, i);
}

void batch_set_node_nout_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, unsigned int *v, size_t v_size, DataCommMode data_mode) {
	batch_set_shared_field<unsigned int, sharedMirror, setOp>(ctx, &ctx->nout, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_add_node_nout_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, unsigned int *v, size_t v_size, DataCommMode data_mode) {
	batch_set_shared_field<unsigned int, sharedMaster, addOp>(ctx, &ctx->nout, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_min_node_nout_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, unsigned int *v, size_t v_size, DataCommMode data_mode) {
	batch_set_shared_field<unsigned int, sharedMaster, minOp>(ctx, &ctx->nout, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void bitset_residual_clear_cuda(struct CUDA_Context *ctx) {
	ctx->residual.is_updated.cpu_rd_ptr()->reset_all();
}

float get_node_residual_cuda(struct CUDA_Context *ctx, unsigned LID) {
	float *residual = ctx->residual.data.cpu_rd_ptr();
	return residual[LID];
}

void set_node_residual_cuda(struct CUDA_Context *ctx, unsigned LID, float v) {
	float *residual = ctx->residual.data.cpu_wr_ptr();
	residual[LID] = v;
}

void add_node_residual_cuda(struct CUDA_Context *ctx, unsigned LID, float v) {
	float *residual = ctx->residual.data.cpu_wr_ptr();
	residual[LID] += v;
}

void min_node_residual_cuda(struct CUDA_Context *ctx, unsigned LID, float v) {
	float *residual = ctx->residual.data.cpu_wr_ptr();
	if (residual[LID] > v)
		residual[LID] = v;
}

void batch_get_node_residual_cuda(struct CUDA_Context *ctx, unsigned from_id, float *v) {
	batch_get_shared_field<float, sharedMaster, false>(ctx, &ctx->residual, from_id, v);
}

void batch_get_node_residual_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t *v_size, DataCommMode *data_mode) {
	batch_get_shared_field<float, sharedMaster, false>(ctx, &ctx->residual, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_get_mirror_node_residual_cuda(struct CUDA_Context *ctx, unsigned from_id, float *v) {
	batch_get_shared_field<float, sharedMirror, false>(ctx, &ctx->residual, from_id, v);
}

void batch_get_mirror_node_residual_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t *v_size, DataCommMode *data_mode) {
	batch_get_shared_field<float, sharedMirror, false>(ctx, &ctx->residual, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_get_reset_node_residual_cuda(struct CUDA_Context *ctx, unsigned from_id, float *v, float i) {
	batch_get_shared_field<float, sharedMirror, true>(ctx, &ctx->residual, from_id, v, i);
}

void batch_get_reset_node_residual_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t *v_size, DataCommMode *data_mode, float i) {
	batch_get_shared_field<float, sharedMirror, true>(ctx, &ctx->residual, from_id, bitset_comm, offsets, v, v_size, data_mode, i);
}

void batch_set_node_residual_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t v_size, DataCommMode data_mode) {
	batch_set_shared_field<float, sharedMirror, setOp>(ctx, &ctx->residual, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_add_node_residual_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t v_size, DataCommMode data_mode) {
	batch_set_shared_field<float, sharedMaster, addOp>(ctx, &ctx->residual, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_min_node_residual_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t v_size, DataCommMode data_mode) {
	batch_set_shared_field<float, sharedMaster, minOp>(ctx, &ctx->residual, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void bitset_value_clear_cuda(struct CUDA_Context *ctx) {
	ctx->value.is_updated.cpu_rd_ptr()->reset_all();
}

float get_node_value_cuda(struct CUDA_Context *ctx, unsigned LID) {
	float *value = ctx->value.data.cpu_rd_ptr();
	return value[LID];
}

void set_node_value_cuda(struct CUDA_Context *ctx, unsigned LID, float v) {
	float *value = ctx->value.data.cpu_wr_ptr();
	value[LID] = v;
}

void add_node_value_cuda(struct CUDA_Context *ctx, unsigned LID, float v) {
	float *value = ctx->value.data.cpu_wr_ptr();
	value[LID] += v;
}

void min_node_value_cuda(struct CUDA_Context *ctx, unsigned LID, float v) {
	float *value = ctx->value.data.cpu_wr_ptr();
	if (value[LID] > v)
		value[LID] = v;
}

void batch_get_node_value_cuda(struct CUDA_Context *ctx, unsigned from_id, float *v) {
	batch_get_shared_field<float, sharedMaster, false>(ctx, &ctx->value, from_id, v);
}

void batch_get_node_value_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t *v_size, DataCommMode *data_mode) {
	batch_get_shared_field<float, sharedMaster, false>(ctx, &ctx->value, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_get_mirror_node_value_cuda(struct CUDA_Context *ctx, unsigned from_id, float *v) {
	batch_get_shared_field<float, sharedMirror, false>(ctx, &ctx->value, from_id, v);
}

void batch_get_mirror_node_value_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t *v_size, DataCommMode *data_mode) {
	batch_get_shared_field<float, sharedMirror, false>(ctx, &ctx->value, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_get_reset_node_value_cuda(struct CUDA_Context *ctx, unsigned from_id, float *v, float i) {
	batch_get_shared_field<float, sharedMirror, true>(ctx, &ctx->value, from_id, v, i);
}

void batch_get_reset_node_value_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t *v_size, DataCommMode *data_mode, float i) {
	batch_get_shared_field<float, sharedMirror, true>(ctx, &ctx->value, from_id, bitset_comm, offsets, v, v_size, data_mode, i);
}

void batch_set_node_value_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t v_size, DataCommMode data_mode) {
	batch_set_shared_field<float, sharedMirror, setOp>(ctx, &ctx->value, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_add_node_value_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t v_size, DataCommMode data_mode) {
	batch_set_shared_field<float, sharedMaster, addOp>(ctx, &ctx->value, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

void batch_min_node_value_cuda(struct CUDA_Context *ctx, unsigned from_id, unsigned long long int *bitset_comm, unsigned int *offsets, float *v, size_t v_size, DataCommMode data_mode) {
	batch_set_shared_field<float, sharedMaster, minOp>(ctx, &ctx->value, from_id, bitset_comm, offsets, v, v_size, data_mode);
}

