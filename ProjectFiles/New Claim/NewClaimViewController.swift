import UIKit
import MapKit
import CoreLocation
import AVFoundation
import ContactsUI

class NewClaimViewController: UIViewController {

	@IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var addressLabel: UILabel!
	
	@IBOutlet weak var transcriptionTextView: UITextView!
	@IBOutlet weak var recordingTimerLabel: UILabel!
	@IBOutlet weak var playButton: UIButton!
	@IBOutlet weak var recordButton: UIButton!
	
	@IBOutlet weak var photoStackView: UIStackView!
	@IBOutlet weak var photoStackHeightConstraint: NSLayoutConstraint!
	
	@IBOutlet weak var partiesInvolvedStackView: UIStackView!
	
	var wasSubmitted = false
	
	let locationManager = CLLocationManager()
	let regionRadius = 150.0
	let geoCoder = CLGeocoder()
	var geoCodedAddress: CLPlacemark?
	var geoCodedAddressText = ""
	
	var recordingSession: AVAudioSession!
	var incidentRecorder: AVAudioRecorder?
	var audioPlayer: AVAudioPlayer!
	var meterTimer: Timer?
	var transcribedText = ""
	var isPlaying = false
	
	var imagePickerCtrl: UIImagePickerController!
	var selectedImages: [UIImage] = []
	
	var contacts: [CNContact] = []
	let contactPicker = CNContactPickerViewController()

	var alert:UIAlertController!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		initMapViewExtension()
		initAVRecordingExtension()
		self.transcriptionTextView.delegate = self
	
	}

	@IBAction func submitClaim(_ sender: UIBarButtonItem) {
		uploadClaimTransaction()
	}
	
	@IBAction func playPauseAudioTapped(_ sender: UIButton) {
		toggleAudio()
	}
	
	@IBAction func startOrStopRecordingTapped(_ sender: UIButton) {
		toggleRecording()
	}
	
	@IBAction func addPhotoTapped(_ sender: UIButton) {
		addPhoto()
	}
	
	@IBAction func editInvolvedPartiesTapped(_ sender: UIButton) {
		presentContactPicker()
	}
}

extension NewClaimViewController: UITextViewDelegate {
	func textViewDidEndEditing(_ textView: UITextView) {
		self.transcribedText = self.transcriptionTextView.text
	}
}