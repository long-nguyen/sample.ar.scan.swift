//
//  ViewController.swift
//  ARMuseum
//
//  Created by Nguyen Tien LONG on 6/5/19.
//  Copyright © 2019 Nguyen Tien LONG. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

struct ObjectInfo {
    let facts:[String]
    let titlePos: (x:Float, y: Float)
    let name: String
}

let objectURL = "https://dl.dropboxusercontent.com/s/kvt454j7mm7najb/long_bag.arobject"

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    private var worldConf: ARWorldTrackingConfiguration?
    private let objectInfo = ObjectInfo(facts: ["My Bag", "Very clean", "Very stable, used for 4 years"], titlePos: (x: -0.2, y: 0.2), name: "Long's Bag")

    override func viewDidLoad() {
        super.viewDidLoad()
        self.initView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.isObjectAvailable() {
            self.loadLocalObject()
            self.startSession()
        } else {
            self.fetchObject()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    private func startSession() {
        if let configuration = worldConf {
            sceneView.session.run(configuration)
        }
    }
    
    private func initView() {
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = .showFeaturePoints
        
        worldConf = ARWorldTrackingConfiguration()
        
        guard let refImage = ARReferenceImage.referenceImages(inGroupNamed: "AR Images", bundle: nil) else {
            fatalError("No image")
        }
        worldConf?.detectionImages = refImage

        //Load file from bundle
//        guard let refObjects = ARReferenceObject.referenceObjects(inGroupNamed: "AR objects", bundle: nil) else {
//            fatalError("No object")
//        }
//        worldConf?.detectionObjects = refObjects
        
    }
    
    private func isObjectAvailable() ->Bool {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        if let pathComponent = url.appendingPathComponent("long_bag.arobject") {
            let filePath = pathComponent.path
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
                return true
            }
        }
        return false
    }
    
    private func loadLocalObject() {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        if let pathComponent = url.appendingPathComponent("long_bag.arobject") {
            if let refObjects = try? ARReferenceObject(archiveURL: pathComponent.absoluteURL) {
                worldConf?.detectionObjects = [refObjects]
            }
        }
    }
    
    //DOwnload file from internet then add it to arscene
    private func fetchObject() {
        self.downloadFile { (result) in
            if result {
                self.loadLocalObject()
                self.startSession()
            }
        }
    }
    
    private func downloadFile(_ completion: @escaping (Bool)->Void ) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        var request = URLRequest(url: URL(string: objectURL)!)
        request.httpMethod = "GET"
        let task = session.dataTask(with: request) { (data, response, error) in
            if (error == nil) {
                // Success
                DispatchQueue.main.async {
                    
                    //Store file
                    let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
                    let url = NSURL(fileURLWithPath: path)
                    if let pathComponent = url.appendingPathComponent("long_bag.arobject"), let dt = data as NSData? {
                        let filePath = pathComponent.absoluteURL
                        if dt.write(to: filePath, atomically: true) {
                            completion(true)
                        } else {
                            completion(false)
                        }
                    } else {
                        completion(false)
                    }
                }
            }
            else {
                // Failure
                completion(false)
            }
        }
        task.resume()
    }
  
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let error = error as? ARError, let code = ARError.Code(rawValue: error.errorCode) else {
            return
        }
        switch code {
        case .cameraUnauthorized:
            print("camera need permission")
        default:
            print("Unknown error")
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .limited(let reason):
            NSLog("Reason code \(reason)")
        case .normal:
            NSLog("Good camera")
        case .notAvailable:
            NSLog("No camera")
        }
    }
}

extension ViewController: ARSCNViewDelegate {
    
    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor {
            NSLog("Founb image")
            handleFoundImage(imageAnchor, node)
        } else if let objectAnchor = anchor as? ARObjectAnchor {
            NSLog("Founb object")
            handleFoundObject(objectAnchor, node)
        }
    }
    
    private func handleFoundImage(_ anchor:ARImageAnchor, _ node: SCNNode) {
        let size = anchor.referenceImage.physicalSize
        //Create video node to add it to scene
        if let videoNode = makeDinosauVideo(size: size) {
            node.addChildNode(videoNode)
            node.opacity = 1
        }
    }
    
    private func handleFoundObject(_ object: ARObjectAnchor, _ node: SCNNode) {
        let titleNode = createTitleNode()
        node.addChildNode(titleNode)
    }
    
    private func createTitleNode() -> SCNNode {
        let title = SCNText(string: objectInfo.name, extrusionDepth: 0.6)
        let titleNode = SCNNode(geometry: title)
        titleNode.scale = SCNVector3(0.005, 0.005, 0.01)
        titleNode.position = SCNVector3(objectInfo.titlePos.x, objectInfo.titlePos.y, 0)
        
        //set color
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.green
        title.materials = [material]
        
        return titleNode
    }
    
    private func makeDinosauVideo(size: CGSize) -> SCNNode? {
        guard let videoUrl = Bundle.main.url(forResource: "dinosaur", withExtension: "mp4") else {
            return nil
        }
        let avPlayerItem = AVPlayerItem(url: videoUrl)
        let avPlayer = AVPlayer(playerItem: avPlayerItem)
        avPlayer.play()
        
        //Auto replay
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) { (notification) in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }
        
        let avMaterial = SCNMaterial()
        avMaterial.diffuse.contents = avPlayer
        
        let videoPlane = SCNPlane(width: size.width, height: size.height)
        videoPlane.materials = [avMaterial]
        
        //Return a node to be added to sceneKit, it contains materials
        //because the image is flat so we can use SCNPlane
        let videoNode = SCNNode(geometry: videoPlane)
        videoNode.eulerAngles.x = -.pi/2
        
        return videoNode
    }
    
   
}
