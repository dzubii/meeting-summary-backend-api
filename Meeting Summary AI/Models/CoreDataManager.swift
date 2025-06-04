import CoreData
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MeetingSummaryAI")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    func createMeeting(title: String) -> Meeting {
        let meeting = Meeting(context: context)
        meeting.id = UUID()
        meeting.title = title
        meeting.date = Date()
        meeting.isProcessing = false
        saveContext()
        return meeting
    }
    
    func fetchMeetings() -> [Meeting] {
        let request = NSFetchRequest<Meeting>(entityName: "Meeting")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Meeting.date, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching meetings: \(error)")
            return []
        }
    }
    
    func deleteMeeting(_ meeting: Meeting) {
        context.delete(meeting)
        saveContext()
    }
} 