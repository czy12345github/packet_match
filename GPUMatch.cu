#include "GPUMatch.h"

#include <fstream>
#include <sstream>
#include <iostream>
#include <string>

#include <cuda_runtime.h>

__device__ bool is_equal(uint8_t *data1, uint8_t *data2, uint16_t len){
  for(uint16_t i = 0; i < len; ++i){
    if(data1[i] != data2[i]) return false;
  }
  return true;
}

__device__ int data_match(uint8_t *data, uint16_t len, struct Rule *rules, int numOfRules){
  struct Rule *rule;
  int n;
  for(int i = 0; i < numOfRules; ++i){
    rule = rules + i;
    if(len < rule->size) continue;
    n = len - rule->size + 1;
    for(int j = 0; j < n; ++j){
      if(is_equal(rule->content, data+j, rule->size)) return i;
    }
  }
  return -1;
}

__global__ void gpu_filter_packets(struct Packet *pkts, struct Rule *rules, int numOfRules, int *result){
  int index = blockDim.x * blockIdx.x + threadIdx.x;
  int start = index * pktsPerThread;
  for(int i = start; i < start + pktsPerThread; ++i){
    result[i] = data_match(pkts[i].data, pkts[i].pkt_len, rules, numOfRules);
  }
}

GPUMatch::GPUMatch(std::string ruleFile):
force_quit(false), array_num(0), has_data(false){
  cudaMalloc(&gpu_pkts, ArraySize * sizeof(struct Packet));
  cudaMalloc(&gpu_match_result, ArraySize * sizeof(int));

  cpu_match_result = new int[ArraySize];

  read_rules(ruleFile);
}

GPUMatch::~GPUMatch(){
  cudaFree(gpu_pkts);

  delete []cpu_rules;
  cudaFree(gpu_rules);

  delete []cpu_match_result;
  cudaFree(gpu_match_result);
}

void GPUMatch::read_rules(std::string ruleFile){
  std::ifstream ifs(ruleFile);

  std::vector<std::vector<int>> rules;

  std::string line;

  int x;
  while(getline(ifs, line)){
    std::istringstream iss(line);
    std::vector<int> data;
    iss >> std::hex;
    while(iss >> x) data.push_back(x);
    rules.push_back(data);
  }
  ifs.close();

  int N = rules.size();
  cpu_rules = new Rule[N];
  for(int i = 0; i < N; ++i){
    cpu_rules[i].size = rules[i].size();
    for(int j = 0; j < rules[i].size(); ++j){
      cpu_rules[i].content[j] = (uint8_t)(0xff & rules[i][j]);
    }
  }
  numOfRules = N;

  cudaMalloc(&gpu_rules, N * sizeof(struct Rule));
  cudaMemcpy(gpu_rules, cpu_rules, N * sizeof(struct Rule), cudaMemcpyHostToDevice);
}

void GPUMatch::process(){
  struct Packet *pkts;

  while(!force_quit){

    if(has_data){
      q_m.lock();
      pkts = q.front();
      q.pop();
      --array_num;
      if(array_num == 0) has_data = false;
      q_m.unlock();

      process_pkts(pkts);
    }
  }
}

void GPUMatch::process_pkts(struct Packet *pkts){
  cudaMemcpy(gpu_pkts, pkts, ArraySize * sizeof(struct Packet), cudaMemcpyHostToDevice);

  gpu_filter_packets<<<numBlocks, threadsPerBlock>>>(gpu_pkts, gpu_rules, numOfRules, gpu_match_result);
  cudaDeviceSynchronize();

  cudaMemcpy(cpu_match_result, gpu_match_result, ArraySize * sizeof(int), cudaMemcpyDeviceToHost);

  for(int i = 0; i < ArraySize; ++i){
    if(cpu_match_result[i] >= 0){
      std::cout << pkts[i].src_ip << " " << pkts[i].dst_ip << " " << cpu_match_result[i] << std::endl;
    }
  }

  free(pkts);
}
