https://kubernetes.io/docs/concepts/cluster-administration/device-plugins/ 翻译
# 硬件插件
**功能状态**: k8s v1.10 beta  
_beta版的意义_:   
* 版本号包含beta(比如v2beta3).
* 代码被仔细测试过.未了确保功能安全,默认使能.  
* 支持总体功能不会终止,虽然细节可能改变.  
* 条目或者目标的语义可能在随后的beta版本中以不协调的方式改变.当发生类似情况,我们会提供迁移至下一版本的操作说明.这个可能要求删除,编辑和重建API对象.编辑进程要求一些思想.同时在编辑期间依赖该功能的应用可能需要停止一段时间.  
* 由于潜在的不协调版本变化仅推荐给无商业风险的用户.若是有混合集群可以独立地升级,则不需要考虑这个风险.
* __请尝试我们的beta功能并反馈我们相关信息!在它们脱离beta之后,我们将不会做过多改变.__

在k8s v1.8时我们开始提供一种硬件插件架构给供应商通过无修改k8s核心代码的方式上报资源给kubelet.不需要编写额外的k8s代码,供应商可以实现同时能支持手动和Daemonset形式的部署硬件插件.目标支持硬件包括GPU,共性能网卡,FPGA,转接线缆及其他要求供应商特定初始化设置的计算资源.  
* 硬件插件注册
* 硬件插件执行
* 硬件插件部署
* 例子

## 硬件插件注册
硬件插件功能被DevicePlugins管理启用状态,在v1.10前是默认关闭的.当硬件插件功能使能,kubelet将开放注册gRPC服务:
```
service Registration {
	rpc Register(RegisterRequest) returns (Empty) {}
}
```
一个硬件插件可以通过kubelet的gRPC服务注册本身.在注册时,硬件插件需要发送一下信息:  
* unix socket的名称  
* API版本号
* 想要上报的硬件资源名称.硬件资源命名需要遵从[扩展资源命名规范](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/#extended-resources)类似vendor-domain/resource.以NvidiaGPU举例则是nvidia.com/gpu.  

在成功注册之后,硬件插件将向kubelet发送所用它当前所管理的硬件列表,kubelet将根据上报内容更新API的服务.例如,硬件插件在kubelet上注册了vendor-domain/foo且上报了两个健康设备位于一个节点,该节点的状态将暴露两个vendor-domain/foo.  
接着,用户可以请求创建一个使用该资源的容器,遵从一下要求:  
* 扩展资源仅支持整数级别的请求且无法超额分配.  
* 资源无法在容器间分享.  
假定一个k8s集群运行的硬件插件上报某些节点的资源vendor-domain/resource,以下是一个用户pod请求该资源的例子:
```
apiVersion: v1
kind: Pod
metadata:
  name: demo-pod
spec:
  containers:
    - name: demo-container-1
      image: k8s.gcr.io/pause:2.0
      resources:
        limits:
          vendor-domain/resource: 2 # requesting 2 vendor-domain/resource
```
## 硬件插件执行
一个硬件插件的通用的工作流有以下步骤:  
* 初始化.在这期间, 硬件插件执行供应商自定义的硬件初始化设置来使硬件处于就绪状态.  
* 该插件通过Unix socket下的主机路径:/var/lib/kubelet/device-plugins/启动gRPC服务,需要执行以下接口:
```
service DevicePlugin {
      // ListAndWatch returns a stream of List of Devices
      // Whenever a Device state change or a Device disappears, ListAndWatch
      // returns the new list
      rpc ListAndWatch(Empty) returns (stream ListAndWatchResponse) {}

      // Allocate is called during container creation so that the Device
      // Plugin can run device specific operations and instruct Kubelet
      // of the steps to make the Device available in the container
      rpc Allocate(AllocateRequest) returns (AllocateResponse) {}
}
```
* 该插件通过以下主机路径的Unix socket注册到kubelet:  
/var/lib/kubelet/device-plugins/kubelet.sock.  
* 在成功注册后,该硬件插件将以自身的服务模式运行,在监控设备健康及设备状态变化时,它也有为Allocate gRPC 服务请求的处理功能.在Allocate期间,该硬件插件可能需要特定的硬件初始化;例如:GPU cleanup或QRNG安装.如果操作成功,将返回AllocateResponse其中包含了分配给容器硬件的配置.kubelet传递信息给容器运行时间. 

一个硬件插件需要检测klubelet的重启并重新注册到新的kubelet实例上.在当前方式下,一个新kubelet实例启动后将会删除所有存在在的 /var/lib/kubelet/device-plugins下Unix sockets.一个硬件插件可以监控自身Unix socket的删除并重新注册.
## 硬件插件部署
一个硬件插件可以同时支持手动或者DaemonSet方式部署.以DaemonSet部署有利于k8s管理其生命周期.相反的,一种特别的机制需要具有把硬件插件从失败状态恢复的能力.规定路径/var/lib/kubelet/device-plugins要求加密访问,所以一个硬件插件需要以安全加密内容形式运行.若一个硬件插件以DaemonSet形式运行,/var/lib/kubelet/device-plugins必须以卷的形式挂载到pod内.  
k8s硬件插支持仍旧处于alpha.随着开发的推进,API版本将以不协调的方式变化.我们需要硬件插件开发者遵循以下:  
* 查看未来版本的变化.
* 支持不同版本的前后兼容.

若是想要使能DevicePlugins功能且在节点上运行硬件插件需要升级k8s版本,先升级你的硬件插件使之兼容版本再去升级k8s.

## 例子
以下是一些执行实例:
* [NVIDIA GPU device plugin](https://github.com/NVIDIA/k8s-device-plugin)

  *要求[nvidia-docker 2.0](https://github.com/NVIDIA/nvidia-docker)
* [NVIDIA GPU device plugin for COS base OS.](https://github.com/GoogleCloudPlatform/container-engine-accelerators/tree/master/cmd/nvidia_gpu)
* [RDMA device plugin](https://github.com/hustcat/k8s-rdma-device-plugin)
* [Solarflare device plugin](https://github.com/vikaschoudhary16/sfc-device-plugin)