//
//  ViewController.swift
//  ARApp
//
//  Created by Matteo Fusilli on 16/05/2020.
//  Copyright © 2020 Matteo Fusilli. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

struct CollisionCategory: OptionSet {
   let rawValue: Int
   static let missileCategory  = CollisionCategory(rawValue: 1 << 0)
   static let targetCategory = CollisionCategory(rawValue: 1 << 1)
}

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    
    // MARK: - The Ar View
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - buttons
    @IBAction func onBanana(_ sender: Any) {
        fireMissile(type: "banana")
    }
    
    // MARK: - Labels
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var timerLabel: UILabel!
    
    // MARK: - Score and Music:
    var score = 0
    var player: AVAudioPlayer?
    
    //MARK: - fire objects on button press
    
    func getUserVector() -> (SCNVector3, SCNVector3) { // (direction, position)
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            
            return (dir, pos)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        // sceneView.showsStatistics = true
        
        // Add a tapGestureRecognizer to interact with the scene
        //let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        //sceneView.addGestureRecognizer(tapGesture)
        
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
//    @objc
//    func didTap(_ gesture: UITapGestureRecognizer) {
//        let sceneViewTappedOn = gesture.view as! ARSCNView
//        let touchCoordinates = gesture.location(in: sceneViewTappedOn)
//        let hitTest = sceneViewTappedOn.hitTest(touchCoordinates, types: .existingPlaneUsingExtent)
//
//        guard !hitTest.isEmpty, let hitTestResult = hitTest.first else {
//            return
//        }
//
//        let position = SCNVector3(hitTestResult.worldTransform.columns.3.x,
//                                  hitTestResult.worldTransform.columns.3.y,
//                                  hitTestResult.worldTransform.columns.3.z)
//
//        addItemToPosition(position)
//    }
    
    // MARK : - creating object
    
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
    
    // MARK: - fire object
    
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
    
    // MARK: - Add 100 objects at random position around you
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
    
    // MARK: - Play Music
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
    
    // MARK: - Contact Delegate - This function runs when a collision is detected
    
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
    
    
    // MARK: - OLD CODE
    
    // Add the 3D model at that position
//    func addItemToPosition(_ position: SCNVector3) {
//        let scene = SCNScene(named: "art.scnassets/ship.scn")
//
//        DispatchQueue.main.async {
//            if let node = scene?.rootNode.childNode(withName: "ship", recursively: false) {
//                node.position = position
//                self.sceneView.scene.rootNode.addChildNode(node)
//            }
//        }
//    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}


