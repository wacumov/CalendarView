//
//  KDCalendarView.swift
//  KDCalendar
//
//  Created by Michael Michailidis on 02/04/2015.
//  Copyright (c) 2015 Karmadust. All rights reserved.
//

import UIKit
import EventKit

let cellReuseIdentifier = "CalendarDayCell"

let NUMBER_OF_DAYS_IN_WEEK = 7
let MAXIMUM_NUMBER_OF_ROWS = 6

let HEADER_DEFAULT_HEIGHT : CGFloat = 80.0


let FIRST_DAY_INDEX = 0
let NUMBER_OF_DAYS_INDEX = 1
let DATE_SELECTED_INDEX = 2

struct EventLocation {
    let title: String
    let latitude: Double
    let longitude: Double
}

struct CalendarEvent {
    let title: String
    let startDate: Date
    let endDate:Date
}

extension EKEvent {
    var isOneDay : Bool {
        let components = (Calendar.current as NSCalendar).components([.era, .year, .month, .day], from: self.startDate, to: self.endDate, options: NSCalendar.Options())
        return (components.era == 0 && components.year == 0 && components.month == 0 && components.day == 0)
    }
}

protocol CalendarViewDataSource {
    func startDate() -> Date?
    func endDate() -> Date?
}

protocol CalendarViewDelegate {
    
    /* optional */ func calendar(_ calendar : CalendarView, canSelectDate date : Date) -> Bool
    func calendar(_ calendar : CalendarView, didScrollToMonth date : Date) -> Void
    func calendar(_ calendar : CalendarView, didSelectDate date : Date, withEvents events: [CalendarEvent]) -> Void
    /* optional */ func calendar(_ calendar : CalendarView, didDeselectDate date : Date) -> Void
}

extension CalendarViewDelegate {
    func calendar(_ calendar : CalendarView, canSelectDate date : Date) -> Bool { return true }
    func calendar(_ calendar : CalendarView, didDeselectDate date : Date) -> Void { return }
}


class CalendarView: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    
    var dataSource  : CalendarViewDataSource?
    var delegate    : CalendarViewDelegate?
    
    lazy var gregorian : Calendar = {
        
        var cal = Calendar(identifier: Calendar.Identifier.gregorian)
        
        cal.timeZone = TimeZone(abbreviation: "UTC")!
        
        return cal
    }()
    
    var calendar : Calendar {
        return self.gregorian
    }
    
    var direction : UICollectionViewScrollDirection = .horizontal {
        didSet {
            if let layout = self.calendarView.collectionViewLayout as? CalendarFlowLayout {
                layout.scrollDirection = direction
                self.calendarView.reloadData()
            }
        }
    }
    
    fileprivate var startDateCache : Date = Date()
    fileprivate var endDateCache : Date = Date()
    fileprivate var startOfMonthCache : Date = Date()
    fileprivate var todayIndexPath : IndexPath?
    var displayDate : Date?
    
    fileprivate(set) var selectedIndexPaths : [IndexPath] = [IndexPath]()
    fileprivate(set) var selectedDates : [Date] = [Date]()
    
    var allowMultipleSelection : Bool = false {
    
        didSet {
            self.calendarView.allowsMultipleSelection = allowMultipleSelection
        }
    
    }
    
    fileprivate var eventsByIndexPath : [IndexPath:[CalendarEvent]] = [IndexPath:[CalendarEvent]]()
    var events : [EKEvent]? {
        
        didSet {
            
            eventsByIndexPath = [IndexPath:[CalendarEvent]]()
            
            guard let events = events else {
                return
            }
            
            let secondsFromGMTDifference = TimeInterval(NSTimeZone.local.secondsFromGMT())
            
            for event in events {
                
                if event.isOneDay == false {
                    return
                }
                
                let flags: NSCalendar.Unit = [NSCalendar.Unit.month, NSCalendar.Unit.day]
                
                let startDate = event.startDate.addingTimeInterval(secondsFromGMTDifference)
                let endDate = event.endDate.addingTimeInterval(secondsFromGMTDifference)
                
                // Get the distance of the event from the start
                let distanceFromStartComponent = (self.gregorian as NSCalendar).components( flags, from:startOfMonthCache, to: startDate, options: NSCalendar.Options() )
                
                
                let calendarEvent = CalendarEvent(title: event.title, startDate: startDate, endDate: endDate)
                
                let indexPath = IndexPath(item: distanceFromStartComponent.day!, section: distanceFromStartComponent.month!)
                
                if (eventsByIndexPath[indexPath] != nil) {
                    
                    eventsByIndexPath[indexPath]?.append(calendarEvent)
                    
                } else {
                    
                    eventsByIndexPath[indexPath] = [calendarEvent]
                    
                }
            }
            
            DispatchQueue.main.async { self.calendarView.reloadData() }
        }
    }
    
    lazy var headerView : CalendarHeaderView = {
       
        let hv = CalendarHeaderView(frame:CGRect.zero)
        
        return hv
        
    }()
    
    lazy var calendarView : UICollectionView = {
     
        let layout = CalendarFlowLayout()
        layout.scrollDirection = self.direction;
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        
        let cv = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        cv.dataSource = self
        cv.delegate = self
        cv.isPagingEnabled = true
        cv.backgroundColor = UIColor.clear
        cv.showsHorizontalScrollIndicator = false
        cv.showsVerticalScrollIndicator = false
        cv.allowsMultipleSelection = true
        
        return cv
        
    }()
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let heigh = self.frame.size.height - HEADER_DEFAULT_HEIGHT
        let width = self.frame.size.width
        
        self.headerView.frame   = CGRect(x:0.0, y:0.0, width: width, height:HEADER_DEFAULT_HEIGHT)
        self.calendarView.frame = CGRect(x:0.0, y:HEADER_DEFAULT_HEIGHT, width: width, height: heigh)
        
        guard let layout = self.calendarView.collectionViewLayout as? UICollectionViewFlowLayout else { return }

        layout.itemSize = CGSize(width: width / CGFloat(NUMBER_OF_DAYS_IN_WEEK), height: heigh / CGFloat(MAXIMUM_NUMBER_OF_ROWS))
        
        print("self.frame: \(self.frame)")
        
        self.calendarView.reloadData()
        
    }
    
    

    override init(frame: CGRect) {
        super.init(frame :frame)
        self.createSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.createSubviews()
    }
    
    
    
    // MARK: Setup 
    
    fileprivate func createSubviews() {
        
        
        self.clipsToBounds = true
        
        // Register Class
        self.calendarView.register(CalendarDayCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)
        self.calendarView.allowsMultipleSelection = allowMultipleSelection
        
        self.addSubview(self.headerView)
        self.addSubview(self.calendarView)
    }
    
    
    
    // MARK: UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        guard let startDate = self.dataSource?.startDate(), let endDate = self.dataSource?.endDate() else {
            return 0
        }
       
        startDateCache = startDate
        endDateCache = endDate
        
        // check if the dates are in correct order
        
        guard self.gregorian.compare(startDate, to:endDate, toGranularity:.nanosecond) == .orderedAscending else { return 0 }
        
        var firstDayOfStartMonth = self.gregorian.dateComponents([.era, .year, .month], from: startDateCache)
        firstDayOfStartMonth.day = 1
        
        guard let dateFromDayOneComponents = self.gregorian.date(from: firstDayOfStartMonth) else { return 0 }
        
        startOfMonthCache = dateFromDayOneComponents
        
        let today = Date()
        
        if startOfMonthCache.compare(today) == .orderedAscending && endDateCache.compare(today) == .orderedDescending {
            
            let differenceFromTodayComponents = self.gregorian.dateComponents([.month, .day], from: startOfMonthCache, to: today)
            
            self.todayIndexPath = IndexPath(item: differenceFromTodayComponents.day!, section: differenceFromTodayComponents.month!)
            
        }
       
        let differenceComponents = self.gregorian.dateComponents([.month], from: startDateCache, to: endDateCache)
        
        return differenceComponents.month! + 1 // if we are for example on the same month and the difference is 0 we still need 1 to display it
        
    }
    
    var monthInfo : [Int:[Int]] = [Int:[Int]]()
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        var monthOffsetComponents = DateComponents()
        
        // offset by the number of months
        monthOffsetComponents.month = section;
        
        guard
            let correctMonthForSectionDate = self.gregorian.date(byAdding: monthOffsetComponents, to: startOfMonthCache),
            let rangeOfDaysInMonth:Range<Int> = self.gregorian.range(of: .day, in: .month, for: correctMonthForSectionDate) else { return 0 }
        
        let numberOfDaysInMonth = rangeOfDaysInMonth.upperBound
        
        var firstWeekdayOfMonthIndex = self.gregorian.component(.weekday, from: correctMonthForSectionDate)
        firstWeekdayOfMonthIndex = firstWeekdayOfMonthIndex - 1 // firstWeekdayOfMonthIndex should be 0-Indexed
        firstWeekdayOfMonthIndex = (firstWeekdayOfMonthIndex + 6) % 7 // push it modularly so that we take it back one day so that the first day is Monday instead of Sunday which is the default
        
        monthInfo[section] = [firstWeekdayOfMonthIndex, numberOfDaysInMonth]
        
        return NUMBER_OF_DAYS_IN_WEEK * MAXIMUM_NUMBER_OF_ROWS // 7 x 6 = 42
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let dayCell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as! CalendarDayCell
     
        let currentMonthInfo : [Int] = monthInfo[indexPath.section]! // we are guaranteed an array by the fact that we reached this line (so unwrap)
        
        let fdIndex = currentMonthInfo[FIRST_DAY_INDEX]
        let nDays = currentMonthInfo[NUMBER_OF_DAYS_INDEX]
        
        let fromStartOfMonthIndexPath = IndexPath(item: indexPath.item - fdIndex, section: indexPath.section) // if the first is wednesday, add 2
        
        if indexPath.item >= fdIndex && indexPath.item < (fdIndex + nDays) {
            
            dayCell.textLabel.text = String((fromStartOfMonthIndexPath as NSIndexPath).item + 1)
            dayCell.isHidden = false
            
        }
        else {
            dayCell.textLabel.text = ""
            dayCell.isHidden = true
        }
        
        dayCell.isSelected = selectedIndexPaths.contains(indexPath)
        
        if indexPath.section == 0 && indexPath.item == 0 {
            self.scrollViewDidEndDecelerating(collectionView)
        }
        
        if let idx = todayIndexPath {
            dayCell.isToday = (idx.section == indexPath.section && idx.item + fdIndex == indexPath.item)
        }
        
        
        if let eventsForDay = eventsByIndexPath[fromStartOfMonthIndexPath] {
            
            dayCell.eventsCount = eventsForDay.count
            
        } else {
            dayCell.eventsCount = 0
        }

        
        return dayCell
    }
    
    // MARK: UIScrollViewDelegate
    
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let yearDate = self.calculateDateBasedOnScrollViewPosition()
        
        if  let date = yearDate,
            let delegate = self.delegate {
            
            delegate.calendar(self, didScrollToMonth: date)
            self.displayDate = date
        }
        
        
        
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        let yearDate = self.calculateDateBasedOnScrollViewPosition()
        
        if let date = yearDate,
            let delegate = self.delegate {
            delegate.calendar(self, didScrollToMonth: date)
        }
    }
    
    @discardableResult
    func calculateDateBasedOnScrollViewPosition() -> Date? {
        
        let cvbounds = self.calendarView.bounds
        
        var page : Int = 0
        
        switch self.direction {
            
        case .horizontal:
            page = Int(floor(self.calendarView.contentOffset.x / cvbounds.size.width))
            break
            
        case .vertical:
            page = Int(floor(self.calendarView.contentOffset.y / cvbounds.size.height))
            break
        }
        page = page > 0 ? page : 0
        
        var monthsOffsetComponents = DateComponents()
        monthsOffsetComponents.month = page
        
        guard let yearDate = self.gregorian.date(byAdding: monthsOffsetComponents, to: self.startOfMonthCache) else { return nil }
        
        let month = self.gregorian.component(.month, from: yearDate) // get month
        
        let monthName = DateFormatter().monthSymbols[(month-1) % 12] // 0 indexed array
        
        let year = self.gregorian.component(.year, from: yearDate)
        
        
        self.headerView.monthLabel.text = monthName + " " + String(year)
        
        self.displayDate = yearDate
        
        return yearDate;
        
        
    }
    
    
    
    
    // MARK: UICollectionViewDelegate
    
    fileprivate var dateBeingSelectedByUser : Date?
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        
        let currentMonthInfo : [Int] = monthInfo[(indexPath as NSIndexPath).section]!
        let firstDayInMonth = currentMonthInfo[FIRST_DAY_INDEX]
        
        var offsetComponents    = DateComponents()
        offsetComponents.month  = indexPath.section
        offsetComponents.day    = indexPath.item - firstDayInMonth
    
        if let dateUserSelected = self.gregorian.date(byAdding: offsetComponents, to: startOfMonthCache) {
            
            dateBeingSelectedByUser = dateUserSelected
            
            if let delegate = self.delegate { return delegate.calendar(self, canSelectDate: dateUserSelected) }
            else { return true }
            
        }
        
        return false // if date is out of scope
        
    }
    
    func selectDate(_ date : Date) {
        
        guard let indexPath = self.indexPathForDate(date) else {
            return
        }
        
        guard self.calendarView.indexPathsForSelectedItems?.contains(indexPath) == false else {
            return
        }
        
       
        
        self.calendarView.selectItem(at: indexPath, animated: false, scrollPosition: UICollectionViewScrollPosition())
        
        selectedIndexPaths.append(indexPath)
        selectedDates.append(date)
        
    }
    
    func deselectDate(_ date : Date) {
        
        guard let indexPath = self.indexPathForDate(date) else { return }
        
        guard self.calendarView.indexPathsForSelectedItems?.contains(indexPath) == true else { return }
        
        self.calendarView.deselectItem(at: indexPath, animated: false)
        
        guard let index = selectedIndexPaths.index(of: indexPath) else { return }
        
        selectedIndexPaths.remove(at: index)
        selectedDates.remove(at: index)
        
    }
    
    func indexPathForDate(_ date : Date) -> IndexPath? {
        
        let distanceFromStartComponent = self.gregorian.dateComponents([.month, .day], from:startOfMonthCache, to:date)
        
        guard
            let month = distanceFromStartComponent.month,
            let currentMonthInfo = monthInfo[month] else { return nil }
        
        let item        = distanceFromStartComponent.day! + currentMonthInfo[FIRST_DAY_INDEX]
        let indexPath   = IndexPath(item: item, section: month)
        
        return indexPath
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let dateBeingSelectedByUser = dateBeingSelectedByUser else {
            return
        }
        
        let currentMonthInfo : [Int] = monthInfo[(indexPath as NSIndexPath).section]!
    
        let fromStartOfMonthIndexPath = IndexPath(item: (indexPath as NSIndexPath).item - currentMonthInfo[FIRST_DAY_INDEX], section: (indexPath as NSIndexPath).section)
        
        var eventsArray : [CalendarEvent] = [CalendarEvent]()
        
        if let eventsForDay = eventsByIndexPath[fromStartOfMonthIndexPath] {
            eventsArray = eventsForDay;
        }
        
        delegate?.calendar(self, didSelectDate: dateBeingSelectedByUser, withEvents: eventsArray)
        
        
        // Update model
        selectedIndexPaths.append(indexPath)
        selectedDates.append(dateBeingSelectedByUser)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
        guard let dateBeingSelectedByUser = dateBeingSelectedByUser else {
            return
        }
        
        guard let index = selectedIndexPaths.index(of: indexPath) else {
            return
        }
        
        delegate?.calendar(self, didDeselectDate: dateBeingSelectedByUser)
        
        selectedIndexPaths.remove(at: index)
        selectedDates.remove(at: index)
        
        
        if self.calendarView.allowsMultipleSelection {
            self.dateBeingSelectedByUser = selectedDates.last
        } else {
         self.dateBeingSelectedByUser = nil
        
        }
    }
    
    
    func reloadData() {
        self.calendarView.reloadData()
    }
    
    
    func setDisplayDate(_ date : Date, animated: Bool) {
        
        if let dispDate = self.displayDate {
            
            // skip is we are trying to set the same date
            if  date.compare(dispDate) == ComparisonResult.orderedSame { return }
            
            // check if the date is within range
            guard date.isBetween(startDateCache, and: endDateCache) else { return }
            
            guard date.compare(startDateCache) != .orderedAscending && date.compare(endDateCache) != .orderedDescending else { return }
            
            let difference = (self.gregorian as NSCalendar).components([NSCalendar.Unit.month], from: startOfMonthCache, to: date, options: NSCalendar.Options())
            
            let distance : CGFloat = CGFloat(difference.month!) * self.calendarView.frame.size.width
            
            self.calendarView.setContentOffset(CGPoint(x: distance, y: 0.0), animated: animated)
            
            self.calculateDateBasedOnScrollViewPosition()
        }
        
    }

}

extension Date {
    func isBetween(_ date1: Date, and date2: Date) -> Bool {
        return (min(date1, date2) ... max(date1, date2)).contains(self)
    }
}

extension CalendarView{

    func goToMonthWithOffet(_ offet:Int){
        
        if let newDate = (self.displayDate?.applyOffSetOfMonth(calendar: self.calendar, offset: offet)) {
            self.setDisplayDate(newDate, animated: true)
        }
    }
    
    func goToNextMonth(){
        goToMonthWithOffet(1)
    }
    func goToPreviousMonth(){
        goToMonthWithOffet(-1)
    }
    

}
