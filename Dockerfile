FROM ros@sha256:ce590ec63b9707a79a71137c3d019d9142717e6518644bf14d5c8f9c5fbb65b0
SHELL ["/bin/bash", "-c"]

#ros:noetic-ros-core-focal

# Set some environment variables for the GUI
ENV HOME=/root \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=C.UTF-8

# Install cli tools
RUN set -ex && \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install \
            -y --no-install-recommends -o Dpkg::Options::="--force-confnew" \
    build-essential\
    cmake\
    git\
    iputils-ping \
    libfreetype6-dev\
    libgl1-mesa-dev\
    libglu1-mesa-dev\
    libpcre2-dev \
    libxi-dev \
    libxmu-dev\
    nano \
    net-tools \
    python3-dev \
    python3-pip \
    python3 \
    rapidjson-dev \
    ros-noetic-tf \
    ros-noetic-urdfdom-py \
    screen \
    tk-dev\
    vim \
    wget


######################
#OCC :
#####################




RUN dpkg-reconfigure --frontend noninteractive tzdata

RUN wget http://prdownloads.sourceforge.net/swig/swig-4.1.1.tar.gz
RUN tar -zxvf swig-4.1.1.tar.gz
WORKDIR swig-4.1.1
RUN ./configure && make -j$(nproc) && make install


############################################################
# OCCT 7.7.2                                               #
# Download the official source package from git repository #
############################################################
WORKDIR /occt

RUN wget 'https://git.dev.opencascade.org/gitweb/?p=occt.git;a=snapshot;h=cec1ecd0c9f3b3d2572c47035d11949e8dfa85e2;sf=tgz' -O occt-7.7.2.tgz

RUN ls

RUN tar -xvzf occt-7.7.2.tgz # >> extracted_occt772_files.txt
WORKDIR  /occt/occt-cec1ecd
RUN mkdir cmake-build
WORKDIR /occt/occt-cec1ecd/cmake-build

RUN cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DINSTALL_DIR=/opt/build/occt772 -DBUILD_RELEASE_DISABLE_EXCEPTIONS=OFF ..
RUN make -j$(nproc)
RUN make install
RUN echo "/opt/build/occt772/lib" >> /etc/ld.so.conf.d/occt.conf


#############
# pythonocc #
#############


WORKDIR /opt/build
RUN git clone https://github.com/tpaviot/pythonocc-core.git

WORKDIR  mkdir pythonocc_install

WORKDIR /opt/build/pythonocc-core
RUN git checkout 7.7.2


RUN mkdir cmake-build
WORKDIR /opt/build/pythonocc-core/cmake-build

RUN cmake \
 -DOCCT_INCLUDE_DIR=/opt/build/occt772/include/opencascade \
 -DOCCT_LIBRARY_DIR=/opt/build/occt772/lib \
 -DPYTHONOCC_BUILD_TYPE=Release \
 -DPYTHONOCC_MESHDS_NUMPY=ON \
 -DPYTHONOCC_INSTALL_DIR=/opt/build/pythonocc_install \
 ..

RUN cmake -j$(nproc) && make install
ENV PYTHONPATH=/usr/local/lib/python3/dist-packages:$PYTHONPATH
RUN echo 'PYTHONPATH=/usr/local/lib/python3/dist-packages:$PYTHONPATH' >> /etc/bash.bashrc
############
# svgwrite #
############
RUN pip3 install svgwrite numpy matplotlib catkin_tools



WORKDIR /input_step_files
WORKDIR /output_ros_urdf_packages



RUN source /opt/ros/$ROS_DISTRO/setup.bash



WORKDIR /ros_ws


# catkin build
RUN source /opt/ros/$ROS_DISTRO/setup.bash && \
    catkin init && \
    catkin clean -y

WORKDIR /ros_ws/src

RUN git clone https://github.com/ReconCycle/urdf_from_step.git

WORKDIR /ros_ws/src/urdf_from_step

RUN git pull
RUN git rev-parse --short HEAD

WORKDIR /ros_ws


RUN source /opt/ros/$ROS_DISTRO/setup.bash && \
    catkin build


# Always source ros_catkin_entrypoint.sh when launching bash (e.g. when attaching to container)



RUN echo "source /source_ws.sh" >> /root/.bashrc
WORKDIR /
RUN echo "#!/bin/bash" >> /source_ws.sh
RUN echo "set -e" >> /source_ws.sh
RUN echo "source \"/opt/ros/$ROS_DISTRO/setup.bash\" --" >> /source_ws.sh
RUN chmod +x /source_ws.sh
RUN echo "source \"/ros_ws/devel/setup.bash\" --" >> /source_ws.sh
RUN echo "exec \"\$@\"" >> /source_ws.sh
RUN ./source_ws.sh

WORKDIR /ros_ws

ENTRYPOINT ["/source_ws.sh"]
CMD ["bash"]
