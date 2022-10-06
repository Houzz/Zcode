<img src="https://zcode.lk/wp-content/uploads/2020/10/Zcode-logo-1.png" alt="VLCKit logo"> by  &nbsp;&nbsp;&nbsp;&nbsp; <img src="https://user-images.githubusercontent.com/21142711/138073778-45668e41-3958-4258-9abb-560852d875e7.png" alt="VLCKit logo" height="90">

# Zcode Overview
Houzz Xcode plugin  
Zcode is an Xcode plugin designed to prevent human errors when implementing multiple protocols and generating code.

## Table of content
- [Installation](#installation)
- [Features](#features)
  - [Generate: Assert IBOutlets](#generate-assert-iboutlets)
  - [Generate: Cast](#generate-cast)
  - [Generate: Cast read](#generate-cast-read)
  - [Generate: NSCoding](#generate-nscoding)
  - [Generate: NSCopying](#generate-nscopying)
  - [Generate: Init](#generate-init)
  - [Generate: Make Defaults](#generate-make-defaults)
  - [Generate: Multipart Dictionary](#generate-multipart-dictionary)
  - [Generate: Codable](#generate-codable)
  - [Insert: Custom save state functions](#insert-custom-save-state-functions)

## Installation

1. Download latest *Zcode* package from the [Releases](https://github.com/Houzz/Zcode/releases).
1. Copy *Zcode* to your *Applications* folder.
1. Launch *Zcode* once. You can close it immediately afterwards.
1. Go to <kbd>System Preferences</kbd> > <kbd>Extensions</kbd> > <kbd>Xcode Source Editor</kbd> > select <kbd>Zcode</kbd>

## Features

### Generate: Assert IBOutlets
Assert IBoutlets will detect all **@IBOutlets** in a class, and create an assert statement for each and one of them in `viewDidLoad()` or `awakeFromNib()` accordingly.  
  
In case you forgot to implement `viewDidLoad()` or `awakeFromNib()` (depends on the context) - an Xcode warning will appear  
![image](https://user-images.githubusercontent.com/21142711/138058303-7f47170f-8736-4639-b683-c0fd2419d507.png)  
  
Running this command will generate the following code
```swift
class Demo: UIViewController {
    @IBOutlet var test1: UILabel!
    @IBOutlet var test2: UILabel!
    @IBOutlet var test3: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Begin outlet asserts
        assert(test1 != nil, "IBOutlet test1 not connected")
        assert(test2 != nil, "IBOutlet test2 not connected")
        assert(test3 != nil, "IBOutlet test3 not connected")
        // End outlet asserts

    }
}
```
### Generate: Cast
Cast is one of the most popular commands in Zcode. Cast is used when conforming to `DictionaryConvertible` protocol.  
All you have to do is declare the class or struct, inherit from `NSObject` and conform the `DictionaryConvertible` protocol, like so:
```swift
class Demo: NSObject, DictionaryConvertible {
    let id: Int
    let fullName: String?
}
  
```
Of couse this code will generate compilation errors, but after running Zcode's `Generate: Cast` command, it will look like this:
```swift
class Demo: NSObject, DictionaryConvertible {
    let id: Int
    let fullName: String?
    

    func dictionaryRepresentation() -> [String: Any] { // Generated
        var dict = [String: Any]()
        dict["Id"] = id.jsonValue
        dict["FullName"] = fullName?.jsonValue
        // Add custom code after this comment
        return dict
    }

    required init?(dictionary dict: JSONDictionary) { // Generated
        if let v: Int = dict.value(for: "Id") {
            id = v
        } else {
            LogError("Error: Demo.id failed init")
            assert(false, "Please open API ticket if needed")
            return nil
        }
        fullName = nilEmpty(dict.value(for: "FullName"))
        super.init()
        if !awake(with: dict) {
            return nil
        }
    }
}
```
  
# Zcode Comments: #  
To enhance the power of Cast, you can apply your customization using special Zcode comments, maked with the prefix ` //! `  
Given the following demo JSON:
```json
{
	"id": 1,
	"user": {
		"fullName": "John Appleseed",
		"nickname": "Johnny Boi",
		"birthday": 719487660000,
		"isAssigned": true
	},
	"hobby": "Watching Squid Game on Netflix"
}
```
Here are the list of Zcode comments you can use to suit your needs:
1. `//! "User/FullName"` - this comment will populate your property based on this path, accessing nested objects in the JSON hierarchy.
2. `//! msec "User/Birthday"` - At Houzz, we represent dates in milliseconds, so adding `msec` to your Zcode comment will make sure to represent the Date in milliseconds.
3. `=` - Equal sign defines a default value.  
For example, if we're parsing a nullable value, but don't want it to be null, use equal sign with your default value:
```swift
let name: String //! = "Anonymous" "User/FullName"
```
4. `??` - This operator can help use another property as a fallback value, and can be nested multiple times.
```swift
let name: String //! = "Anonymous" "User/FullName ?? User/Nickname"
```
5. `//! ignore` - This comment will tell Zcode to ignore everything regarding this property, and you will have to add your implementation manually after generating the code.  
6. `//! ignore json` - This comment will prevent Zcode from handling this property in `dictionaryRepresentation()` and `nit?(dictionary dict: JSONDictionary)` but it will be included in different protocols such as NSSecureCoding, Codable, etc..
7. `//! custom` - Will automatically call a static parsing function called parse<property name> - which you will have to implement manually.
8. Top of the file comments:
	8.1 `//! zcode: case camelCase` - will parse the JSON properties in **camelCase** 
	8.2 `//! zcode: case CamelCase` - will parse the JSON properties in **CamelCase** 
	8.3 `//! zcode: case screamingSnake` - Will parse the JSON properties in **screaming snake case** (mix of upper case and snake case). e.g `PROJECT_OWNER`
	8.4 `//! zcode: emptyIsNil on/off` - Will treat empty strings as nil
	8.5 `//! zcode: logger off`
9. Zcode generates a unique fingerprint based on the current code, if you change your property types or modify the class, the fingerprint will update after you run the Cast command.  
	9.1 Zcode contains a pre-commit hook, and it make sure that you ran the cast command after modifying your entity. If you forget to run Cast, your code 	     will not be committed and a notification will be shown
	
If you'd like to add some custom behavior prior initialization of your entity, you should implement `awake(with dictionary: JSONDictionary)` and return true/false representing if this property should be initialized or not
```swift
class Demo: NSObject, DictionaryConvertible {
    let dueDate: Date

    func dictionaryRepresentation() -> [String: Any] { // Generated
        var dict = [String: Any]()
        dict["DueDate"] = dueDate.jsonValue
        // Add custom code after this comment
        return dict
    }

    required init?(dictionary dict: JSONDictionary) { // Generated
        if let v: Date = dict.value(for: "DueDate") {
            dueDate = v
        } else {
            LogError("Error: Demo.dueDate failed init")
            assert(false, "Please open API ticket if needed")
            return nil
        }
        super.init()
        if !awake(with: dict) {
            return nil
        }
    }

    func awake(with dictionary: JSONDictionary) -> Bool {
        dueDate < Date() // Due date has not passed yet
    }
    
}
```

We'd like to parse a `Person` object with data based from the JSON above. We can use the power of Zcode comments to our advantage:
```swift
class Person: NSObject, DictionaryConvertible {
    let id: Int
    let name: String //! = "Anonymous" "User/Name ?? User/Nickname"
    let birthday: Date? //! msec "User/Birthday"
    let age: String //! ignore


    func dictionaryRepresentation() -> [String: Any] { // Generated
        var dict = [String: Any]()
        dict["Id"] = id.jsonValue
        var dict1 = dict["User"] as? [String: Any] ?? [String: Any]()
        dict1["Name"] = name.jsonValue
        if let birthday = birthday {
            dict1["Birthday"] = Int(birthday.timeIntervalSince1970 * 1000)
        }
        dict["User"] = dict1
        // Add custom code after this comment
        dict["age"] = "29" // This line was added manually
        return dict
    }

    required init?(dictionary dict: JSONDictionary) { // Generated
        if let v: Int = dict.value(for: "Id") {
            id = v
        } else {
            LogError("Error: Person.id failed init")
            assert(false, "Please open API ticket if needed")
            return nil
        }
        name = nilEmpty(dict.value(for: "User/Name")) ?? nilEmpty(dict.value(for: "User/Nickname")) ?? "Anonymous"
        birthday = dict.value(for: "User/Birthday")
        age = "29" // This line was added manually
        super.init()
        if !awake(with: dict) {
            return nil
        }
    }
}
```
### Generate: Cast read
Similar to [Cast](#generate-cast), Cast read will only generate a `func read(from dict: JSONDictionary)` function.  
The content of the function is also based on the entity's properties, similar to [Cast](#generate-cast).  
Cast read will only populate **variable** fields.  
Following our previous example:
```swift
class Person: NSObject, DictionaryConvertible {
    var name: String //! = "Anonymous" "User/FullName"

    func read(from dict: JSONDictionary) { // Generated
        if let v: String = nilEmpty(dict.value(for: "User/FullName")) {
            name = v
        }

        // Add custom code after this comment
    }
}
```
### Generate: NSCoding
NSCoding will generate code that conforms your entity to NSCoding protocol, based on your properties.  
**Note:** Zcode comments will not affect this code generation command
```swift
class Person: NSCoding {
    var name: String

     required init?(coder aDecoder: NSCoder) { // Generated
        if let v = String.decode(with: aDecoder, fromKey: "name") {
            name = v
        } else {
            return nil
        }
        // Add custom code after this comment
    }

    func encode(with aCoder: NSCoder) { // Generated
        name.encode(with: aCoder, forKey: "name")
        // Add custom code after this comment
    }
}
```
### Generate: NSCopying
NSCopying will generate code that conforms your entity to NSCoding protocol, based on your properties.  
To use this command, your entity must conform to `NSCoding` and `NSCopying` protocols.
**Note:** Zcode comments will not affect this code generation command
```swift
class Person: NSCoding, NSCopying {
    var name: String

    func encode(with aCoder: NSCoder) { // Generated
        name.encode(with: aCoder, forKey: "name")
        // Add custom code after this comment
    }

     required init?(coder aDecoder: NSCoder) { // Generated
        if let v = String.decode(with: aDecoder, fromKey: "name") {
            name = v
        } else {
            return nil
        }
        // Add custom code after this comment
    }

    func copy(with zone: NSZone? = nil) -> Any { // Generated
        let aCopy = try! NSKeyedUnarchiver.unarchivedObject(ofClasses: [Person.self], from: NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true))!
        // Add custom code after this comment
        return aCopy
    }
}
```
### Generate: Init
This command creates an initializer for your entity, based on it's properties.
You can use the default value Zcode comments from [Cast](#generate-cast) to define default values in the initializer.
```swift
class Person {
    let id: Int //! = 0
    let name: String? //! = "Anonymous"
    let birthday: Date

    init(id: Int = 0, name: String? = "Anonymous", birthday: Date) { // Generated Init
        self.id = id
        self.name = name
        self.birthday = birthday
        // Add custom code after this comment
    }
}
```
### Generate: Make Defaults

To use Make Defaults, your entity must inherit from `UserDefaults`, if you forget to do so, an Xcode warning will be shown:
![image](https://user-images.githubusercontent.com/21142711/138086318-5d9ee80c-12b1-40d5-b381-67ba0d01530b.png)
  
This command parses a list of [DefaultKey](https://github.com/Houzz/Zcode/blob/ba61efc46f6a43dfe5de179e1a3d8feebf3b4dc7/Xcode-Extension/DefaultsCommand.swift) and creating a property for each of these keys in a separate extension (generated).  
Each generated property will have the getter and setter.  
  
It's recommended (but not mandatory) to use a static var called `allKeys` which is an array of `DefaultKey` to declare about all of your keys.
```swift
class DemoDefaults: UserDefaults {
    static let allKeys: [DefaultKey] = [
        DefaultKey("id", type: .int, options: [.objc, .write]),
        DefaultKey("name", type: .string, options: [.objc, .write]),
        DefaultKey("isAssigned", type: .bool, options: [.objc, .write])
    ]
}
// MARK: - Generated accessors
extension DemoDefaults {
    @objc public var id: Int {
        get {
            return integer(forKey: "id")
        }
        set {
            set(newValue, forKey: "id")
        }
    }

    @objc public var name: String? {
        get {
            return object(forKey: "name") as? String
        }
        set {
            set(newValue, forKey: "name")
        }
    }

    @objc public var isAssigned: Bool {
        get {
            return bool(forKey: "isAssigned")
        }
        set {
            set(newValue, forKey: "isAssigned")
        }
    }
}
```

### Generate: Multipart Dictionary

:warning: This command is no longer needed, use [Cast](#generate-cast) or [Cast read](#generate-cast-read) instead. :warning:

### Generate: Codable
This command generates `encode(from encoder: Encoder)`, `init(from decoder: Decoder)` and `CodingKeys` enum.  
Your entity must conform to the Codable protocol
```swift
class Person: Codable {
    let name: String

    func encode(to encoder: Encoder) throws { // Generated
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        // Add custom code after this comment
    }

    required init(from decoder: Decoder) throws { // Generated
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeString(forKey: .name)
        // Add custom code after this comment
    }

    private enum CodingKeys: String, CodingKey { // Generated
        case name
        // Add custom code after this comment
    }
}
```
### Insert: Custom save state functions
This command will override the relevant methods used to support restore state, which are available if your class subclass `UIViewController`.
```swift
class DemoViewController: UIViewController {
    private enum CodingKeys: String, CodingKey {
        case <#key#>
    }

    override open  func saveState(to encoder: Any) throws {
        guard let encoder = encoder as? Encoder else { return }
        var container = encoder.container(keyedBy: CodingKeys.self)
        <#Encode view controller state here#>
        try super.saveState(to: encoder)
    }

    override open  func restoreState(from decoder: Any) throws {
        guard let decoder = decoder as? Decoder else { return }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // View is not yet loaded, insert _ = view if need to load view
        <#Decode view controller state here#>
        try super.restoreState(from: decoder)
    }

    // return a view controller, don't call restore on it, if this is a superclass that is not supposed to be saved
    // directly, can omit implementing this function if shouldSaveState return false
    open override class func viewController(using decoder: Any) throws -> UIViewController {
        guard let decoder = decoder as? Decoder else { throw SaveStateError(.notStateDecoder) }
        <#Create view controller here#>
    }

    // Return if we should save state on this controller (can change during controller lifetime)
    open override var shouldSaveState: Bool { true }

}
```

# Deploying a new version
* update `Config.xcconfig` with the new build and config numbers
* create a new tag with the version name
* on your local machine, archive the zcode project
* select "Distribute" using "Development" option
<img width="1017" alt="image" src="https://user-images.githubusercontent.com/20025111/190116691-f634abe7-61f8-4b97-893d-bf52b8f66b61.png">
* select "Automatically sign" option
<img width="741" alt="image" src="https://user-images.githubusercontent.com/20025111/190117019-d05ee290-4a67-4849-b90f-d7a73a3268eb.png">
* compress the generated `Zcode.app` app into `Zcode.zip`
* create a new release using https://github.com/Houzz/Zcode/releases/new
* the new release title is the version number
* drag the zip file into the release and publish!

# Missing Zcode from the xcode menu?

1. Make sure your Xcode is named exactly `Xcode.app` and not something like `Xcode14.app`
2. Make sure zcode is enabled in the extensions manager

<img width="664" alt="image" src="https://user-images.githubusercontent.com/20025111/194265176-71220501-6a3a-4740-ac79-21efe8115901.png">


<img width="659" alt="image" src="https://user-images.githubusercontent.com/20025111/194264986-45a9158b-9176-47ec-91eb-57d73e0db5ad.png">


<img width="655" alt="image" src="https://user-images.githubusercontent.com/20025111/194265038-7db2cd76-4795-4c63-90d3-c1b0e29b9cd6.png">

