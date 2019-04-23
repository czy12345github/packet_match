#ifndef _DATA_TYPES_H
#define _DATA_TYPES_H

#include <stdint.h>

#define PKT_SIZE 1500

#define RULESIZE 64

#define numBlocks 32
#define threadsPerBlock 32
#define pktsPerThread 64

#define TotalThreads (numBlocks * threadsPerBlock)
#define ArraySize (TotalThreads * pktsPerThread)

struct Packet {
  uint32_t src_ip;
  uint32_t dst_ip;
  uint8_t proto;
  uint16_t src_port;
  uint16_t dst_port;

  uint16_t pkt_len;
  uint8_t data[PKT_SIZE];
};

struct Rule {
  uint16_t size;
  uint8_t content[RULESIZE];
};


#endif
