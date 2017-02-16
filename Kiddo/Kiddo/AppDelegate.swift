//
//  AppDelegate.swift
//  Kiddo
//
//  Created by Filiz Kurban on 11/7/16.
//  Copyright © 2016 Filiz Kurban. All rights reserved.
//

import UIKit
import Parse
import ParseUI
import ParseFacebookUtilsV4
import UserNotifications
import Fabric
import Crashlytics


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, PFLogInViewControllerDelegate, PFSignUpViewControllerDelegate, UNUserNotificationCenterDelegate  {

    var window: UIWindow?
    var rootVC: UIViewController?
    private let userDefaults = UserDefaults.standard

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        Fabric.with([Crashlytics.self])

       let configuration = ParseClientConfiguration {
            $0.applicationId = "1G2h3j45Rtf3s"
            $0.clientKey = "1kjHsfg72348nkKnwl2"
            $0.server = "https://kiddoapp.herokuapp.com/parse"
        }

        Parse.initialize(with: configuration)
        PFFacebookUtils.initializeFacebook(applicationLaunchOptions: launchOptions)

        if PFUser.current() == nil && facebookLoginNeeded() {
            let logInViewController = LogInViewController()
            logInViewController.fields = [PFLogInFields.facebook, PFLogInFields.dismissButton]
            logInViewController.delegate = self
            logInViewController.emailAsUsername = false
            logInViewController.signUpController?.delegate = self
            logInViewController.facebookPermissions = ["public_profile", "email"]
            

            window?.rootViewController? = logInViewController
            window?.makeKeyAndVisible()

         }

         fetchImages()

        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (settings) in
            if settings.authorizationStatus != .authorized {
                if let lastNotificationAuthRequest = self.userDefaults.object(forKey: "UserNotificationsDeniedKey") as? Date {
                    if Int(lastNotificationAuthRequest.timeIntervalSinceNow * -1) >= (60*60*24*7) {
                        //It's been more than 7 days since we last asked, good enough, let's ask again.
                        UNUserNotificationCenter.current().requestAuthorization(options: [ .alert, .sound]) {(granted, error) in
                            if granted {
                                //schedule notifications.
                                self.scheduleLocalNotifications()
                                Answers.logCustomEvent(withName: "UserOptedInForNotifications", customAttributes: nil)
                            } else {
                                print("Notification access denied.")
                                let today = Date()
                                self.userDefaults.set(today, forKey: "UserNotificationsDeniedKey")
                                Answers.logCustomEvent(withName: "UserOptedOutForNotifications", customAttributes: nil)
                            }
                        }
                    }
                } else {
                    //If we get here, it's the user's first time launching the app (becaue no UserNotificationsDeniedKey recorded).
                    self.scheduleLocalNotifications()
                }
            }
        })

        window?.makeKeyAndVisible()
        let splashView = UIView(frame: (self.window?.frame)!)
        splashView.backgroundColor = UIColor(red:0.22, green:0.15, blue:0.30, alpha:1.0)
        self.window?.addSubview(splashView)

        let imageView = UIImageView(image: UIImage(named: "kiddo"))
        var imageFrame = imageView.frame
        imageFrame.origin.x = 132.5
        imageFrame.origin.y = 218
        imageView.frame = imageFrame
        self.window?.addSubview(imageView)


        self.window?.bringSubview(toFront: imageView)
        UIView.transition(with: self.window!,
                          duration: 0.75,
                          options: UIViewAnimationOptions.curveEaseInOut,
                          animations: {
                            imageView.alpha = 0.0
                            splashView.alpha = 0.0
                            imageView.transform = CGAffineTransform(scaleX: 2, y: 2);
            //imageView.frame = imageView.frame.offsetBy(dx: 100.0, dy: 100.0)
        }) { (finished) in
            imageView.removeFromSuperview()
            splashView.removeFromSuperview()
        }

        return true
    }

    func fetchImages() {
        let eventDateQuery = PFQuery(className: "EventImage")
        eventDateQuery.findObjectsInBackground { (objects, error) in
            if let objects = objects {
                for object in objects {
                    let imageFile = object["image"] as? PFFile
                    //var dataImage: UIImage
                    imageFile?.getDataInBackground({ (data, error) in
                        let dataImage = UIImage(data: data!)
                        SimpleCache.shared.setImage(dataImage!, key: object.objectId!)
                    })
                }
            }
        }
    }

    func facebookLoginNeeded() -> Bool {
        guard let lastFacebookLoginRequest = userDefaults.object(forKey: "FacebookLoginSkipped") as? Date else { return true }

            if Int(lastFacebookLoginRequest.timeIntervalSinceNow * -1) >= (60*60*24*3) {
                //it's been more than a week since we asked the user to log in. Let's try that again.
                return true
            }

         return false
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("Handle local notification from background or closed")
        //from background this method is called.
    }

    func scheduleLocalNotifications() {

        //time interval is every day for now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: (60*60*24*1), repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Kiddo"
        content.body = "Check out these new events added to Kiddo!"
        content.sound = UNNotificationSound.default()

        let request = UNNotificationRequest(identifier: "textNotification", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) {(error) in
            if let error = error {
                print("Uh oh! We had an error: \(error)")
            }
        }
    }


    //MARK: PFLogInViewControllerDelegate functions

    func log(_ logInController: PFLogInViewController, didLogIn user: PFUser) {
        Answers.logLogin(withMethod: "Facebook", success: 1, customAttributes: ["FacebookLogin": "Success"])

        window?.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
    }

    //To-Do: Need to handle error conditions
    func log(_ logInController: PFLogInViewController, didFailToLogInWithError error: Error?) {
        Answers.logLogin(withMethod: "Facebook", success: 0, customAttributes: ["FacebookLogin": "Error"])

        window?.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()

        let alert = UIAlertController(title: "Facebook Login Failed", message: "Facebook login failed due to an error. We skipped the login step. You can still enjoy Kiddo!", preferredStyle: UIAlertControllerStyle.alert)
        let alertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil)
        alert.addAction(alertAction)

        window?.rootViewController?.present(alert, animated: true, completion: nil)
    }

    //Skipping log in triggers this.
    func logInViewControllerDidCancelLog(in logInController: PFLogInViewController) {

        Answers.logLogin(withMethod: "Facebook", success: 0, customAttributes: ["FacebookLogin": "Skip"])

        self.userDefaults.set(Date(), forKey: "FacebookLoginSkipped")

        window?.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()

        let alert = UIAlertController(title: "Facebook Login Cancelled", message: "No worries! You can still enjoy Kiddo without signing up!", preferredStyle: UIAlertControllerStyle.alert)
        let alertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil)
        alert.addAction(alertAction)


        window?.rootViewController?.present(alert, animated: true, completion: nil)

    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        FBSDKAppEvents.activateApp()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     sourceApplication: String?,
                     annotation: Any) -> Bool {
        return FBSDKApplicationDelegate.sharedInstance().application(application,
                                                                     open: url,
                                                                     sourceApplication: sourceApplication,
                                                                     annotation: annotation)
    }   

}

