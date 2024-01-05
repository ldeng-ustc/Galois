/*
 * This file belongs to the Galois project, a C++ library for exploiting
 * parallelism. The code is being released under the terms of the 3-Clause BSD
 * License (a copy is located in LICENSE.txt at the top-level directory).
 *
 * Copyright (C) 2018, The University of Texas at Austin. All rights reserved.
 * UNIVERSITY EXPRESSLY DISCLAIMS ANY AND ALL WARRANTIES CONCERNING THIS
 * SOFTWARE AND DOCUMENTATION, INCLUDING ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR ANY PARTICULAR PURPOSE, NON-INFRINGEMENT AND WARRANTIES OF
 * PERFORMANCE, AND ANY WARRANTY THAT MIGHT OTHERWISE ARISE FROM COURSE OF
 * DEALING OR USAGE OF TRADE.  NO WARRANTY IS EITHER EXPRESS OR IMPLIED WITH
 * RESPECT TO THE USE OF THE SOFTWARE OR DOCUMENTATION. Under no circumstances
 * shall University be liable for incidental, special, indirect, direct or
 * consequential damages or loss of profits, interruption of business, or
 * related expenses which may arise from use of Software or Documentation,
 * including but not limited to those resulting from defects in Software and/or
 * Documentation, or loss or inaccuracy of data of any kind.
 */

#include "galois/LargeArray.h"
#include "galois/graphs/FileGraph.h"
#include "galois/graphs/OfflineGraph.h"

#include "llvm/Support/CommandLine.h"

#include <boost/iostreams/filtering_streambuf.hpp>
#include <boost/iostreams/filter/gzip.hpp>
#include <boost/mpl/if.hpp>
#include <algorithm>
#include <deque>
#include <fstream>
#include <iostream>
#include <ios>
#include <limits>
#include <cstdint>
#include <vector>
#include <random>
#include <chrono>
#include <regex>
#include <fcntl.h>
#include <cstdlib>

namespace cll = llvm::cl;

static cll::opt<std::string>
    inputFilename(cll::Positional, cll::desc("<input file>"), cll::Required);
static cll::opt<std::string>
    outputFilename(cll::Positional, cll::desc("<output file>"), cll::Required);
static cll::opt<bool> useData("useData", cll::desc("Use data"),
                              cll::init(false));
static cll::opt<bool> useSmallData("32bitData", cll::desc("Use 32 bit data"),
                                   cll::init(false));
static cll::opt<unsigned long long>
    numNodes("numNodes", cll::desc("Total number of nodes given."),
             cll::init(0));

union dataTy {
  int64_t ival;
  double dval;
  float fval;
  int32_t i32val;
};

void perEdge(std::istream& is,
             std::function<void(uint64_t, uint64_t, dataTy)> fn) {

  uint64_t bytes      = 0;
  uint64_t counter    = 0;
  uint64_t totalBytes = 0;

  auto timer      = std::chrono::system_clock::now();
  auto timerStart = timer;

  while (is) {
    uint64_t src, dst;
    dataTy data;
    is.read(reinterpret_cast<char*>(&src), sizeof(src));
    if(is.fail()) {
      std::cerr << "Failed to read src\n";
      continue;
    }
    bytes += sizeof(src);
    totalBytes += sizeof(src);
    is.read(reinterpret_cast<char*>(&dst), sizeof(dst));
    if(is.fail()) {
      std::cerr << "Failed to read dst\n";
      continue;
    }
    bytes += sizeof(dst);
    totalBytes += sizeof(dst);
    
    if(useData) {
      if(useSmallData) {
        is.read(reinterpret_cast<char*>(&data.i32val), sizeof(data.i32val));
        bytes += sizeof(data.i32val);
        totalBytes += sizeof(data.i32val);
      } else {
        is.read(reinterpret_cast<char*>(&data.ival), sizeof(data.ival));
        bytes += sizeof(data.ival);
        totalBytes += sizeof(data.ival);
      }
      if(is.fail()) {
        std::cerr << "Failed to read data\n";
        continue;
      }
    }

    ++counter;

    if (counter == 1024 * 128) {
      counter     = 0;
      auto timer2 = std::chrono::system_clock::now();
      std::cout << "Scan: "
                << (double)bytes /
                       std::chrono::duration_cast<std::chrono::microseconds>(
                           timer2 - timer)
                           .count()
                << " MB/s\n";
      timer = timer2;
      bytes = 0;
    }

    fn(src, dst, data);
  }
  auto timer2 = std::chrono::system_clock::now();
  std::cout << "File Scan: "
            << (double)totalBytes /
                   std::chrono::duration_cast<std::chrono::microseconds>(
                       timer2 - timerStart)
                       .count()
            << " MB/s\n";
}

void go(std::istream& input) {
  try {
    std::deque<uint64_t> edgeCount;
    perEdge(
        input,
        [&edgeCount](uint64_t src, uint64_t, dataTy) {
          if (edgeCount.size() <= src)
            edgeCount.resize(src + 1);
          ++edgeCount[src];
        });
    
    std::cout << "Num nodes: " << edgeCount.size() << "\n";
    std::cout << "Edge count of nodes[:20]: " << std::endl;
    for(size_t i = 0ull; i < std::min((size_t)20, edgeCount.size()); ++i) {
      std::cout << edgeCount[i] << " ";
    }

    input.clear();
    input.seekg(0, std::ios_base::beg);
    galois::graphs::OfflineGraphWriter outFile(outputFilename, useSmallData);
    outFile.setCounts(edgeCount);
    perEdge(
        input,
        [&outFile, &edgeCount](uint64_t src, uint64_t dst, dataTy data) {
          auto off = --edgeCount[src];
          if(!useData)
            outFile.setEdge(src, off, dst);
          else if (useSmallData)
            outFile.setEdge(src, off, dst, data.i32val);
          else
            outFile.setEdge(src, off, dst, data.ival);
        });
  } catch (const char* c) {
    std::cerr << "Failed with: " << c << "\n";
    abort();
  }
}

int main(int argc, char** argv) {
  llvm::cl::ParseCommandLineOptions(argc, argv);
  //  std::ios_base::sync_with_stdio(false);
  std::cout << "Data will be " << (useSmallData ? 4 : 8) << " Bytes\n";

  std::ifstream infile(inputFilename, std::ios_base::in | std::ios_base::binary);
  if (!infile) {
    std::cout << "Failed to open " << inputFilename << "\n";
    return 1;
  }

  go(infile);

  return 0;
}
