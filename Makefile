USER=$(shell whoami)
WORKDIR=$(shell pwd)
WORKDIR_ESCAPED=$(subst /,\\/,$(WORKDIR))

build: sfz apt sfizz-config plugins augene-ng setup-plugin-run-env generate-music

apt:
	echo "Installing sfizz from OBS..."
	echo 'deb http://download.opensuse.org/repositories/home:/sfztools:/sfizz:/develop/xUbuntu_20.04/ /' | sudo tee /etc/apt/sources.list.d/home:sfztools:sfizz:develop.list
	curl -fsSL https://download.opensuse.org/repositories/home:sfztools:sfizz:develop/xUbuntu_20.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_sfztools_sfizz_develop.gpg > /dev/null
	sudo apt update
	echo y | sudo apt install sfizz
	echo y | sudo apt-get install xvfb wget unzip libc6 \
                 libcurl3-gnutls-dev  libfreetype6-dev libgcc1 libjpeg-dev \
                 libpng-dev libstdc++6 libwebkit2gtk-4.0-dev libx11-6 \
                 libxext6 zlib1g  make g++ mesa-common-dev libasound2-dev \
                 libjack-jackd2-dev ladspa-sdk \
                 doxygen libgrpc++-dev libgrpc-dev \
                 libprotobuf-dev protobuf-compiler protobuf-compiler-grpc \
                 graphviz cmake ninja-build \
		 lv2-dev liblilv-dev libsuil-dev \
		 ffmpeg


sfizz-config:
	sed -e "s/%%WORKDIR%%/$(WORKDIR_ESCAPED)/" sfizz-settings.xml
	if [ ! -f ~/.config/SFZTools/sfizz/settings.xml ] ; then \
		mkdir -p ~/.config/SFZTools/sfizz/ ; \
		sed -e "s/%%WORKDIR%%/$(WORKDIR_ESCAPED)/" sfizz-settings.xml > ~/.config/SFZTools/sfizz/settings.xml ; \
	fi
	cat ~/.config/SFZTools/sfizz/settings.xml # FIXME: remove debugging


sfz: vpo3 freepats nbo
	ls -l sounds/sfz # FIXME: remove debugging
	find -L sounds/sfz -name *.sfz || exit 0 # FIXME: remove debugging

vpo3:
	pwd
	mkdir -p sounds/sfz
	# FIXME: copy should not be forced
	if [ ! -d sounds/sfz/Virtual-Playing-Orchestra3 ]; then \
		rm -rf sounds/sfz/Virtual-Playing-Orchestra3 ; \
		#ln -s $(WORKDIR)/external/Virtual_Playing_Orchestra_3 sounds/sfz/Virtual-Playing-Orchestra3 ; \
		cp -R $(WORKDIR)/external/Virtual_Playing_Orchestra_3 sounds/sfz/Virtual-Playing-Orchestra3 ; \
		ln -s $(WORKDIR)/external/Virtual_Playing_Orchestra_3 sounds/sfz/Virtual_Playing_Orchestra_3 ; \
	fi

freepats: freepats.stamp
freepats.stamp: DrawbarOrganEmulation-SFZ-20190712.tar.xz
	mkdir -p sounds/sfz/
	cd sounds/sfz && tar xvf $(WORKDIR)/DrawbarOrganEmulation-SFZ-20190712.tar.xz || exit 1
	touch freepats.stamp
DrawbarOrganEmulation-SFZ-20190712.tar.xz:
	if [ ! -f DrawbarOrganEmulation-SFZ-20190712.tar.xz ] ; then \
		wget https://freepats.zenvoid.org/Organ/DrawbarOrganEmulation/DrawbarOrganEmulation-SFZ-20190712.tar.xz ; \
	fi

nbo: nbo.stamp
nbo.stamp: nbo_2.zip
	mkdir -p sounds/sfz/
	cd sounds/sfz/ && unzip $(WORKDIR)/nbo_2.zip || exit 1
	touch nbo.stamp
nbo_2.zip:
	if [ ! -f nbo_2.zip ] ; then \
		wget http://www.bandshed.net/sounds/sfz/nbo_2.zip ; \
	fi

plugins: setup-simple-reverb setup-sfizz

setup-simple-reverb:
	if [ ! -f simple-reverb.stamp ] ; then \
	cd external/SimpleReverb && patch -i ../../simple-reverb.patch && cd ../../ && touch simple-reverb.stamp || exit 1 ; \
	fi

	cmake -S external/SimpleReverb/ -B simple-reverb-build
	cmake --build simple-reverb-build/
	sudo mkdir -p /usr/local/lib/vst3
	sudo cp -R simple-reverb-build/SimpleReverb_artefacts/VST3/SimpleReverb.vst3 /usr/local/lib/vst3

setup-sfizz:
	if [ ! -d /usr/local/lib/vst3/sfizz.vst3 ] ; then \
		sudo mkdir -p /usr/local/lib/vst3/ ; \
		sudo cp -R /usr/lib/vst3/sfizz.vst3 /usr/local/lib/vst3/sfizz.vst3 ; \
	fi

# not in use
setup-sfizz-studiorack: setup-studiorack
	sudo studiorack plugin install studiorack/sfizz/sfizz
	# studiorack installs the plugin into weird path.
	# Fortunately we don't want to depend on *their* installation path,
	# so we use it just to skip builds from source and symlink to it
	# from the *right* path.
	if [ ! -d /usr/local/lib/vst3/sfizz.vst3 ] ; then \
		sudo mkdir -p /usr/local/lib/vst3/ ; \
		sudo ln -s /usr/local/lib/VST3/studiorack/sfizz/sfizz/1.1.1/sfizz.vst3 /usr/local/lib/vst3/sfizz.vst3 ; \
	fi
# not in use
setup-studiorack:
	sudo npm install @studiorack/cli -g

augene-ng:
	echo sdk.dir=/home/`whoami`/Android/Sdk > external/augene-ng/kotractive-project/local.properties
	echo sdk.dir=/home/`whoami`/Android/Sdk > external/augene-ng/augene-project/local.properties

	cd external/augene-ng/kotractive-project && ./gradlew publishToMavenLocal
	cd external/augene-ng/augene-project && ./gradlew publishToMavenLocal augene-console:build

	if [ ! -f tracktion-juce.stamp ] ; then \
		cd external/augene-ng/external/tracktion_engine/modules/juce ; \
		patch -i ../../../../../../juce-plugin-scanner-headless.patch -p1 ; \
		cd ../../../../../.. ; \
		touch tracktion-juce.stamp ; \
	fi

	if [ ! -f augene-headless.stamp ] ; then \
		cd external/augene-ng ; \
		patch -i ../../augene-headless-plugin-scan.patch -p1 ; \
		cd ../../ ; \
		touch augene-headless.stamp ; \
	fi

	# cd external/augene-ng/ && bash build-lv2-plugin-host.sh
	cd external/augene-ng/ && bash build-augene-player.sh

# Setup plugins ready for playing ------------

setup-plugin-run-env: setup-juce-plugin-list export-plugin-support-mml

setup-juce-plugin-list:
	ls /usr/local/lib/vst3
	external/augene-ng/augene-player/build/AugenePlayer_artefacts/AugenePlayer --scan-plugins
	cat ~/.config/augene-player/Settings.xml

export-plugin-support-mml:
	external/augene-ng/augene-player/build/AugenePlayer_artefacts/AugenePlayer --export-mml

# Generate Music -----------------------------

generate-music: generate-mars-sfizz-mp3

generate-mars-sfizz-mp3: \
	compile-to-tracktionedit \
	render-wav \
	convert-wav-to-mp3

compile-to-tracktionedit:
	java -jar external/augene-ng/augene-project/augene-console/build/libs/augene-console-0.1.0-SNAPSHOT.jar `pwd`/external/augene-ng/samples/mars/mars_sfizz.augene

render-wav:
	rm -f external/augene-ng/samples/mars/mars_sfizz.wav
	external/augene-ng/augene-player/build/AugenePlayer_artefacts/AugenePlayer --render-wav external/augene-ng/samples/mars/mars_sfizz.tracktionedit 

convert-wav-to-mp3:
	ffmpeg -i external/augene-ng/samples/mars/mars_sfizz.wav -ab 128k -af silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-90dB external/augene-ng/samples/mars/mars_sfizz.mp3

