verilator \
-cc -exe --public --trace --savable \
--compiler msvc +define+SIMULATION=1 \
-O3 --x-assign fast --x-initial fast --noassert \
--converge-limit 6000 \
-Wno-fatal \
--top-module top sim.v \
../rtl/cosmacelf.sv \
../rtl/cdp1802.sv \
../rtl/dpram.sv \
../rtl/pixie/pixie_dp.v \
../rtl/pixie/pixie_dp_back_end.v \
../rtl/pixie/pixie_dp_frame_buffer.v \
../rtl/pixie/pixie_dp_front_end.v \
../rtl/pixie/pixie_video.v \
../rtl/pixie/pixie_video_studioii.v