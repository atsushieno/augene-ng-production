USER=$(shell whoami)

build: apt sfizz-config plugins sfz augene-ng generate-mars-sfizz-mp3

apt:
	echo "Installing sfizz from OBS..."
	echo 'deb http://download.opensuse.org/repositories/home:/sfztools:/sfizz/xUbuntu_20.04/ /' | sudo tee /etc/apt/sources.list.d/home:sfztools:sfizz.list
	curl -fsSL https://download.opensuse.org/repositories/home:sfztools:sfizz/xUbuntu_20.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_sfztools_sfizz.gpg > /dev/null
	sudo apt update
	echo y | sudo apt install sfizz
	echo y | sudo apt-get install xvfb wget unzip libc6 \
                 libcurl3-gnutls-dev  libfreetype6-dev libgcc1 libjpeg-dev \
                 libpng-dev libstdc++6 libwebkit2gtk-4.0-dev libx11-6 \
                 libxext6 zlib1g  make g++ mesa-common-dev libasound2-dev \
                 libjack-jackd2-dev ladspa-sdk \
                 doxygen libgrpc++-dev libgrpc-dev \
                 libprotobuf-dev protobuf-compiler protobuf-compiler-grpc \
                 graphviz cmake ninja-build


sfizz-config:
	if [ ! -f ~/.config/SFZTools/sfizz/settings.xml ] ; then \
		mkdir -p ~/.config/SFZTools/sfizz/ ; \
		sed -e "s/%%USER%%/$(USER)/" sfizz-settings.xml > ~/.config/SFZTools/sfizz/settings.xml ; \
	fi


sfz: vpo3 freepats

vpo3:
	mkdir -p sounds/sfz
	rm sounds/sfz/Virtual-Playing-Orchestra3
	cd sounds/sfz && ln -s ../../external/Virtual_Playing_Orchestra_3 Virtual-Playing-Orchestra3 && cd ../..

freepats: freepats.stamp
freepats.stamp: DrawbarOrganEmulation-SFZ-20190712.tar.xz
	mkdir -p sounds/sfz/
	cd sounds/sfz && tar xvf ../../DrawbarOrganEmulation-SFZ-20190712.tar.xz && cd ../.. || exit 1
	touch freepats.stamp
DrawbarOrganEmulation-SFZ-20190712.tar.xz:
	wget https://freepats.zenvoid.org/Organ/DrawbarOrganEmulation/DrawbarOrganEmulation-SFZ-20190712.tar.xz

nbo: nbo.stamp
nbo.stamp: nbo_2.zip
	mkdir -p sounds/sfz/
	cd sounds/sfz/ && unzip ../../nbo_2.zip && cd ../../ || exit 1
	touch nbo.stamp
nbo_2.zip:
	wget http://www.bandshed.net/sounds/sfz/nbo_2.zip

plugins: setup-simple-reverb

setup-simple-reverb:
	if [ ! -f simple-reverb.stamp ] ; then \
	cd external/SimpleReverb && patch -i ../../simple-reverb.patch && cd ../../ && touch simple-reverb.stamp || exit 1 ; \
	fi

	cmake -S external/SimpleReverb/ -B simple-reverb-build
	cmake --build simple-reverb-build/
	sudo cp -R simple-reverb-build/SimpleReverb_artefacts/VST3/SimpleReverb.vst3 /usr/local/lib/vst3

augene-ng:
	echo sdk.dir=/home/`whoami`/Android/Sdk > external/augene-ng/kotractive-project/local.properties
	echo sdk.dir=/home/`whoami`/Android/Sdk > external/augene-ng/augene-project/local.properties

	cd external/augene-ng/kotractive-project && ./gradlew publishToMavenLocal
	cd external/augene-ng/augene-project && ./gradlew publishToMavenLocal augene-console:build

	cd external/augene-ng/ && bash build-lv2-plugin-host.sh
	cd external/augene-ng/ && bash build-augene-player.sh

generate-mars-sfizz-mp3: \
	setup-juce-plugin-list \
	export-plugin-support-mml \
	compile-to-tracktionedit \
	render-wav \
	convert-wav-to-mp3

setup-juce-plugin-list:
	external/augene-ng/augene-player/build/AugenePlayer_artefacts/AugenePlayer --scan-plugins

export-plugin-support-mml:
	external/augene-ng/augene-player/build/AugenePlayer_artefacts/AugenePlayer --export-mml

compile-to-tracktionedit:
	java -jar external/augene-ng/augene-project/augene-console/build/libs/augene-console-0.1.0-SNAPSHOT.jar `pwd`/external/augene-ng/samples/mars/mars_sfizz.augene

render-wav:
	rm -f external/augene-ng/samples/mars/mars_sfizz.wav
	external/augene-ng/augene-player/build/AugenePlayer_artefacts/AugenePlayer --render-wav external/augene-ng/samples/mars/mars_sfizz.tracktionedit 

convert-wav-to-mp3:
	ffmpeg -i external/augene-ng/samples/mars/mars_sfizz.wav -ab 192k -af silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-90dB external/augene-ng/samples/mars/mars_sfizz.mp3

