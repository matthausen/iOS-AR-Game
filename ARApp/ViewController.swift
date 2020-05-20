//
//  ViewController.swift
//  ARApp
//
//  Created by Matteo Fusilli on 16/05/2020.
//  Copyright © 2020 Matteo Fusilli. All rights reserved.
//

import UIKit
import ARKit
import RealityKit
//import SceneKit
import MultipeerConnectivity

struct CollisionCategory: OptionSet {
   let rawValue: Int
   static let missileCategory  = CollisionCategory(rawValue: 1 << 0)
   static let targetCategory = CollisionCategory(rawValue: 1 << 1)
}

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, SCNPhysicsContactDelegate {
    
    // MARK: - Global variables
    @IBOutlet var sceneView: ARSCNView!
    
    @IBAction func onBanana(_ sender: Any) {
        fireMissile(type: "banana")
    }
    
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var sendMapButton: UIButton!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var mappingStatusLabel: UILabel!
    
    var multipeerSession: MultipeerSession!
    
    // MARK: - Score and Music:
    var score = 0
    var player: AVAudioPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        
        // Show statistics such as fps and timing information
        // sceneView.showsStatistics = true
        
        // Add a tapGestureRecognizer to interact with the scene
        //let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        //sceneView.addGestureRecognizer(tapGesture)
        
        // Initiate mulipeerSession
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
        
        sceneView.scene.physicsWorld.contactDelegate = self
        addTargetNodes()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """)
        }
        
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - Multi User Session
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        // updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    /// - Tag: CheckMappingStatus
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        print("Running")
        switch frame.worldMappingStatus {
        case .notAvailable, .limited:
            sendMapButton.isEnabled = false
        case .extending:
            sendMapButton.isEnabled = !multipeerSession.connectedPeers.isEmpty
        case .mapped:
            sendMapButton.isEnabled = !multipeerSession.connectedPeers.isEmpty
        @unknown default:
            sendMapButton.isEnabled = false
        }
        mappingStatusLabel.text = "frame.worldMappingStatus.description"
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    // MARK: - Session Observers
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay.
        sessionInfoLabel.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required.
        sessionInfoLabel.text = "Session interruption ended"
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
        guard error is ARError else { return }

        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]

        // Remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")

        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetTracking(nil)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    /// - Tag: GetWorldMap
    @IBAction func shareSession(_ button: UIButton) {
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { print("Error: \(error!.localizedDescription)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
            self.multipeerSession.sendToAllPeers(data)
        }
    }
    
    /// - Tag: ReceiveData
    var mapProvider: MCPeerID?
    func receivedData(_ data: Data, from peer: MCPeerID) {
        
        do {
            if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                // Run the session with the received world map.
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = .horizontal
                configuration.initialWorldMap = worldMap
                sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                
                // Remember who provided the map for showing UI feedback.
                mapProvider = peer
            }
            else
            if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
                // Add anchor to the session, ARSCNView delegate adds visible content.
                sceneView.session.add(anchor: anchor)
            }
            else {
                print("unknown data recieved from \(peer)")
            }
        } catch {
            print("can't decode data recieved from \(peer)")
        }
    }
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty && multipeerSession.connectedPeers.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move around to map the environment, or wait to join a shared session."
            
        case .normal where !multipeerSession.connectedPeers.isEmpty && mapProvider == nil:
            let peerNames = multipeerSession.connectedPeers.map({ $0.displayName }).joined(separator: ", ")
            message = "Connected with \(peerNames)."
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing) where mapProvider != nil,
             .limited(.relocalizing) where mapProvider != nil:
            message = "Received map from \(mapProvider!.displayName)."
            
        case .limited(.relocalizing):
            message = "Resuming session — move to where you were when the session was interrupted."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        default:
            // No feedback needed when tracking is normal and planes are visible.
            // (Nor when in unreachable limited-tracking states.)
            message = ""
            
        }
        
        sessionInfoLabel.text = message
        // sessionInfoView.isHidden = message.isEmpty
    }
    
    @IBAction func resetTracking(_ sender: UIButton?) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    
    
    //MARK: - Fire Objects func
    func getUserVector() -> (SCNVector3, SCNVector3) { // (direction, position)
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            
            return (dir, pos)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
    
    // MARK: - Create object func
    func createMissile(type : String)->SCNNode{
        var node = SCNNode()
        
        //using case statement to allow variations of scale and rotations
        switch type {
        case "banana":
            let scene = SCNScene(named: "art.scnassets/banana.dae")
            node = (scene?.rootNode.childNode(withName: "Cube_001", recursively: true)!)!
            node.scale = SCNVector3(0.2,0.2,0.2)
            node.name = "banana"
        case "axe":
            let scene = SCNScene(named: "art.scnassets/axe.dae")
            node = (scene?.rootNode.childNode(withName: "axe", recursively: true)!)!
            node.scale = SCNVector3(0.3,0.3,0.3)
            node.name = "bathtub"
        default:
            node = SCNNode()
        }
        
        //the physics body governs how the object interacts with other objects and its environment
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.physicsBody?.isAffectedByGravity = false
        
        node.physicsBody?.categoryBitMask = CollisionCategory.missileCategory.rawValue
        node.physicsBody?.collisionBitMask = CollisionCategory.targetCategory.rawValue
        
        return node
    }
    
    // MARK: - Fire object func
    func fireMissile(type : String){
        var node = SCNNode()
        //create node
        node = createMissile(type: type)
        
        //get the users position and direction
        let (direction, position) = self.getUserVector()
        node.position = position
        var nodeDirection = SCNVector3()
        switch type {
        case "banana":
            nodeDirection  = SCNVector3(direction.x*4,direction.y*4,direction.z*4)
            node.physicsBody?.applyForce(nodeDirection, at: SCNVector3(0.1,0,0), asImpulse: true)
        case "axe":
            nodeDirection  = SCNVector3(direction.x*4,direction.y*4,direction.z*4)
            node.physicsBody?.applyForce(SCNVector3(direction.x,direction.y,direction.z), at: SCNVector3(0,0,0.1), asImpulse: true)
        default:
            nodeDirection = direction
        }
        
        //move node
        node.physicsBody?.applyForce(nodeDirection , asImpulse: true)
        
        //add node to scene
        sceneView.scene.rootNode.addChildNode(node)
    }
    
    // MARK: - Create nodes func
    func addTargetNodes(){
        for index in 1...100 {
            
            var node = SCNNode()
            
            if (index > 9) && (index % 10 == 0) {
                let scene = SCNScene(named: "art.scnassets/chicken.dae")
                node = (scene?.rootNode.childNode(withName: "Chicken", recursively: true)!)!
                node.scale = SCNVector3(1,1,1)
                node.name = "Chicken"
            }
            else{
                let scene = SCNScene(named: "art.scnassets/alien.dae")
                node = (scene?.rootNode.childNode(withName: "alien", recursively: true)!)!
                node.scale = SCNVector3(0.02,0.02,0.02)
                node.name = "alien"
            }
            
            node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            node.physicsBody?.isAffectedByGravity = false
            
            //place randomly, within thresholds
            node.position = SCNVector3(randomFloat(min: -10, max: 10),randomFloat(min: -4, max: 5),randomFloat(min: -10, max: 10))
            
            //rotate
            let action : SCNAction = SCNAction.rotate(by: .pi, around: SCNVector3(0, 1, 0), duration: 1.0)
            let forever = SCNAction.repeatForever(action)
            node.runAction(forever)
            
            node.physicsBody?.categoryBitMask = CollisionCategory.targetCategory.rawValue
            node.physicsBody?.contactTestBitMask = CollisionCategory.missileCategory.rawValue
            
            //add to scene
            sceneView.scene.rootNode.addChildNode(node)
        }
    }
    
    //create random float between specified ranges
    func randomFloat(min: Float, max: Float) -> Float {
        return (Float(arc4random()) / 0xFFFFFFFF) * (max - min) + min
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - Play Music fucn
    func playSound(sound: String, format: String) {
        guard let url = Bundle.main.url(forResource: sound, withExtension: format)else {return}
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)

            guard let player = player else {return}
            player.play()
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    // MARK: - Collision detection func
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
         print("** Collision!! " + contact.nodeA.name! + " hit " + contact.nodeB.name!)
        
        if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.targetCategory.rawValue
            || contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.targetCategory.rawValue {
            
            if (contact.nodeA.name! == "Chicken" || contact.nodeB.name! == "Chicken") {
                score+=5
            }else{
                score+=1
            }
            
            DispatchQueue.main.async {
                contact.nodeA.removeFromParentNode()
                contact.nodeB.removeFromParentNode()
                self.scoreLabel.text = String(self.score)
            }
            
            playSound(sound: "explosion", format: "mp3")
            let explosion = SCNParticleSystem(named: "Explode", inDirectory: nil)
            contact.nodeB.addParticleSystem(explosion!)
        }
    }
}


