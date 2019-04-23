#ifndef _GPUMATCH_H
#define _GPUMATCH_H

#include "data_types.h"

#include <queue>
#include <mutex>
#include <string>

class GPUMatch {
public:
  GPUMatch(std::string ruleFile);
  ~GPUMatch();

  void add_pkts(struct Packet *cpu_pkts){
    q_m.lock();
    q.push(cpu_pkts);
    ++array_num;
    if(!has_data) has_data = true;
    q_m.unlock();
  }

  void process();

  void quit(){
    force_quit = true;
  }

private:
  volatile bool force_quit;

  std::queue<struct Packet *> q;
  std::mutex q_m;
  int array_num;
  int max_array_num;
  volatile bool has_data;

  struct Packet *gpu_pkts;

  struct Rule *cpu_rules;
  struct Rule *gpu_rules;
  int numOfRules;

  int *cpu_match_result;
  int *gpu_match_result;

  void process_pkts(struct Packet *cpu_pkts);

  void read_rules(std::string ruleFile);
};

#endif
