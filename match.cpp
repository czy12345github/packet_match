#include "data_types.h"
#include "GPUMatch.h"

#include <iostream>

using namespace std;

extern "C" void pass_cpu_pkts(struct Packet *pkts);

extern "C" void quit_gpu_processing();

extern "C" void gpu_process();

static GPUMatch match("rules");

void pass_cpu_pkts(struct Packet *pkts){
  match.add_pkts(pkts);
}

void quit_gpu_processing(){
  cout << "quit_gpu_processing" << endl;
  match.quit();
}

void gpu_process(){
  match.process();
}
