source 'https://github.com/CocoaPods/Specs.git'

use_frameworks!

def sharedPods
    pod 'RxSwift', :git => 'https://github.com/ReactiveX/RxSwift.git', :branch => 'master'
    pod 'RxCocoa', :git => 'https://github.com/ReactiveX/RxSwift.git', :branch => 'master'
end

target 'iOSContact' do
    platform :ios, '8.0'
    sharedPods
end

target 'watchContact Extension' do
    platform :watchos, '3.2'
    sharedPods
end

target 'tvContact' do
    platform :tvos, '9.0'
    sharedPods
end

target 'osxContact' do
    platform :osx, '10.10'
    sharedPods
end

