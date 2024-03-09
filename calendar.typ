/*
** Configuration
*/
#let config = yaml("config.yaml")
#(config.height = eval(config.height))
#(config.width = eval(config.width))
#(config.toolbar-width = eval(config.toolbar-width))
#(config.fontsize = eval(config.fontsize))
#(config.margin = eval(config.margin))
#(config.top-margin = eval(config.top-margin))

#let hairline = 0.5pt
#let ruleline = hairline + gray
#let borderline = hairline + black

#set pagebreak(weak: true)


// TODO: this should take parameters for calendar, holidays, and events files.
// --input events=events.yaml --input holidays=holidays.yaml
// access as sys.inputs.<events|holidays>
#let calendar = yaml("calendar.yaml")
#let events = json("events.json")
#let holidays = yaml("holidays.yaml")

// A lot of boilerplate data depends on the first days of the first and
// last months in the calendar datafile
#let fday = calendar.first().first()
#let lday = calendar.last().first()

// Having the month names and weekdays upfront is useful as well.
#let monthnames = calendar.map(month => month.first().name)
#let weekdays = calendar.first().map(day => day.weekday).slice(0, count: 7)

/*
** Page Layout / Base Style
*/
#set text(
    font: config.font,
    size: config.fontsize,
    weight: "light",
    // number-type: "old-style",
)

#set page(
    height: config.height,
    width: config.width,
    margin: if config.toolbar-side == "left" {
	(left: config.margin + config.toolbar-width, top: config.top-margin, rest: config.margin)
    } else {
	(right: config.margin + config.toolbar-width, top: config.top-margin, rest: config.margin)
    },
    header-ascent: config.margin
)


/*
** Utility functions
*/

// dict constructor, ala Python
// See: https://github.com/typst/typst/pull/3383
#let from-pairs(pairs) = {
  for (k, v) in pairs {
    ((k): v)
  }
}

#let chunker(arr, sz) = {
    return range(0, arr.len(), step: sz).map(pos => {
	arr.slice(pos, count: sz)
    })
}

// Return a label based on the items given
#let labelize(..items) = {
    let key = items.pos().map(str).join("-")
    return label(key)
}

/*
** Header/Navigation Functions
*/

// https://github.com/typst/typst/issues/528#issuecomment-1494318510
#let rotatex(angle, body) = style(styles => {
  let size = measure(body,styles)
  box(inset:(x: -size.width/2+(size.width*calc.abs(calc.cos(angle))+size.height*calc.abs(calc.sin(angle)))/2,
             y: -size.height/2+(size.height*calc.abs(calc.cos(angle))+size.width*calc.abs(calc.sin(angle)))/2),
             rotate(body,angle))
})
#let sideways = rotatex.with(-90deg)


// which one to highlight
#let tab-list(items, current: (), vertical: false, rotate-text: false, inset: 5pt, ..grid-args) = {
    set text(size: 1.2em)
    let cells = items.pairs().map(
	((txt, loc)) => (
	    if txt in current {
		link(loc)[#grid.cell(fill: black, inset:inset, text(fill: luma(200))[#txt])] // why is the cell fill ignored???
	    } else {
		link(loc)[#grid.cell(inset: inset)[#txt]]
	    }
	)
    )

    let args = grid-args.named() + (inset: 0pt, columns: cells.len())
    if vertical {
	args.columns = 1
	args.rows = cells.len()
    }
    if rotate-text {
	grid(..args, ..cells.map(sideways))
    } else {
	grid(..args, ..cells)
    }
}
#let htab-list = tab-list.with(stroke: (x, y) => if x > 0 {(left: borderline)})
#let vtab-list=tab-list.with(
    vertical: true,
    rotate-text: true,
    inset: (left: 9pt, right: 9pt, rest: 10pt),
    stroke: (x, y) => if y > 0 {(right: borderline, top: borderline)} else {(right: borderline)}
)

#let page-nav(title, lbl: none, prev: none, next: none, subtitle: none) = {
    let large = text.with(size: 2.8em)
    let small = text.with(size: 1.1em)
    let back(loc) = {return link(loc)[\u{29FC}#h(2pt)]}
    let forward(loc) = {return link(loc)[#h(2pt)\u{29FD}]}

    let (cols, cells) = (1, ())

    if prev != none {
	cols += 1
	cells.push(grid.cell(rowspan:2, [#large()[#back(prev)]]))
    }
    if lbl == none {
	lbl = labelize(title)
    }
    cells.push(grid.cell(rowspan: 2, [#large()[#title #lbl]]))
    if subtitle != none {
	cols += 1
	cells.push(small(weight: "semibold")[#align(top, subtitle.top)])
    }
    if next != none {
	cols += 1
	cells.push(grid.cell(rowspan: 2, [#large()[#forward(next)]]))
    }
    if subtitle != none {
	cells.push(small()[#align(bottom, subtitle.bottom)])
    }

    return grid(columns: cols, rows: 2, inset: (top: 0pt, bottom: 0pt, rest: 4pt), ..cells)
}

#let header(left-side, right-side) = {
    box(left-side)
    h(1fr)
    box(right-side)
    if config.clear-top-right-corner {
	box(width: 8mm)
    }
    v(0pt) // (zero vspace still takes up more than without it!)
    box(line(length:100%, stroke: 1pt))
}

#let sidebar(..sides) = {
    let toolbar-width = config.toolbar-width
    place(dx: - toolbar-width - 2mm,
	stack(dir: ttb, spacing: 1fr,
	    ..sides.pos()
	)
    )
}

// This should help reduce boilerplate, since the sidebar will only change the active tabs:
#let main-sidebar(quarters: (), months: ()) = {
    sidebar(
	if "quarterly" in config.include {
	    vtab-list(
		from-pairs(
		    range(0, 12, step: 3).enumerate(start: 1).map(
			((qtr, mon)) => (
			    "Q" + str(qtr),
			    labelize(calendar.at(mon).first().year, "Q"+str(qtr))
			)
		    )
		) ,
		current: quarters
	    )
	},
	if "monthly" in config.include {
	    vtab-list(
		from-pairs(
		    calendar.map(month => (
			month.first().name.slice(0, count: 3),
			labelize(month.first().year, month.first().name)
		    )
		    )
		),
		current: months
	    )
	},
    )
}


/*
** Calendar functions
*/
#let smallmonth(month, include-weeks: false, current-day: none) = {
    // Get the first day for convenience
    let d = month.first()
    set align(center)
    set grid.cell(inset: 0.55em)

    if "monthly" in config.include {
	link(labelize(d.year, d.name))[=== #d.name]
    } else {
	[=== #d.name]
    }
    let weekday-letters = weekdays.map(it => it.first())

    let cells = ()
    if include-weeks {
	cells += (grid.cell()[W],)
    }
    cells += weekday-letters
    // need to handle rolling over to week 1 in the next year!
    let prev_week = 0
    for (i, day) in month.enumerate() {
	if include-weeks and calc.rem(i, 7) == 0 {
	    cells.push(link(labelize(day.year + if day.week < prev_week { 1 } else { 0 }, "W" + str(day.week)))[#day.week])
	    prev_week = day.week
	}
	if day.month == day.name {
	    let active = false
	    if current-day == day.day {
		active = true
	    }
	    if "daily" in config.include {
		cells.push(grid.cell()[#day.day])
		// can't push links unless I create all the daily pages...
		// cells.push(link(labelize(day.year, day.name, day.day))[#grid.cell()[#day.day]])
	    } else {
		cells.push(grid.cell()[#day.day])
	    }	
	} else {
	    cells.push(none)
	}
    }

    grid(
	columns: if include-weeks { 8 } else { 7 },
	align: center,
	stroke: (x, y) => if y == 0 {(top: borderline, bottom: borderline)} + if include-weeks and x == 0 {(right: borderline)},
	..cells
    )
}


/*
** Annual calendar page
*/

#let annual-page() = {
    // The title will be the year
    let title = fday.year

    /* This is a premature optimization for mid-year use... would need to revamp the quarterly functionality, and since this was mostly for teachers, then the quarters aren't even real quarters, and we would need to define the quarters by date or week number in the config or by command line...
 */

    // If the calendar spans a year boundary, use both years as the title.
    let endash = [\u{2013}]
    if fday.year < lday.year {
	title = [#fday.year#endash;#lday.year]
    }

    let tabs = (:)
    if "notes" in config.include {
	tabs.insert("Notes", labelize("Notes Index"))
    }
    tabs.insert("Calendar", labelize(fday.year))

    set page(
	header: header(
	    page-nav(title, lbl: labelize(fday.year)),
	    htab-list(tabs, current: ("Calendar",))
	)
    )

    main-sidebar()

    grid(
	columns: 3,
	column-gutter: 14pt,
	row-gutter: 1fr,
	..calendar.map(smallmonth.with(include-weeks: "weekly" in config.include))
    )

    pagebreak()
}

#if "annual" in config.include {
    [#annual-page()]
}

/*
** Quarterly Pages
*/
#let quarterly-page(qtr, months) = {
    let year = months.at(0).first().year
    let quarter = "Q" + str(qtr)

    let tabs = (:)
    if "notes" in config.include {
	tabs.insert("Notes", labelize("Notes Index"))
    }
    if "annual" in config.include {
	tabs.insert("Calendar", labelize(year))
    }

    set page(
	header: header(
	    page-nav([#quarter], lbl: labelize(year, quarter)),
	    htab-list(tabs)
	)
    )

    main-sidebar(quarters: (quarter,))

    grid(
	columns: 2,
	column-gutter: 3pt,
	stack(dir: ttb, spacing: 1fr,
	    ..months.map(smallmonth.with(include-weeks: "weekly" in config.include))
	),

	locate(loc => [
	    #let current_y = loc.position().y
	    #let remaining_space = config.height - current_y - config.margin * 2 // can't subtract the top-margin because it's in em units...
	    #let lines_num = int(remaining_space / config.fontsize / 2) + 1
	    #for i in range(lines_num) {
		linebreak()
		linebreak()
		box(line(length: 100%, stroke: ruleline))
	    }
	])
    )

    pagebreak()
}

#if "quarterly" in config.include {
    for (qtr, start-month) in range(0, 12, step: 3).enumerate(start: 1) {
	let months = calendar.slice(start-month, count: 3)
	[#quarterly-page(qtr, months)]
    }
}


/*
** Monthly Pages
*/

#let monthly-page(month) = {
    let d = month.first()

    let tabs = (:)
    if "notes" in config.include {
	tabs.insert("Notes", labelize("Notes Index"))
    }
    if "annual" in config.include {
	tabs.insert("Calendar", labelize(d.year))
    }

    set page(
	header: header(
	    page-nav(d.name, lbl: labelize(d.year, d.name)),
	    htab-list(tabs, current: d.name)
	)
    )

    let quarter = "Q" + str(calc.floor(monthnames.position(mon => {d.name == mon}) / 3 + 1))
    main-sidebar(quarters: (quarter,), months: (d.name.slice(0, count: 3),))

    let cells = ()
    if "weekly" in config.include {
	cells = (none, )
    }
    cells += weekdays.map(w => {
	grid.cell(align: top + center, w)
    })

    let prev_week = 0
    for (i, day) in month.enumerate() {
	if calc.rem(i, 7) == 0 and "weekly" in config.include {
	    // cells.push(link(labelize(day.year + if day.week < prev_week { 1 } else { 0 }, "W" + str(day.week)))[#grid.cell(align: left+horizon, sideways()[Week#hide[-]#day.week])])
	    cells.push(grid.cell(align: left + horizon, sideways()[#link(labelize(day.year + if day.week < prev_week { 1 } else { 0 }, "W" + str(day.week)))[Week#hide[-]#day.week]]))
	    prev_week = day.week
	}
	if day.month == day.name {
	    cells.push(grid.cell()[#day.day])
	} else {
	    cells.push(grid.cell(text(gray)[#day.day]))
	}
    }

    grid(
	inset:3pt,
	gutter: -0pt,
	columns: if "weekly" in config.include {(auto, ) + (1fr, ) * 7} else {(1fr, ) * 7},
	rows: (auto, 10%),
	align: top + left,
	stroke: (x, y) => {(bottom: borderline)} + if x > 0 {(left: borderline)},
	..cells
    )

    locate(loc => [
	#let current_y = loc.position().y
	#let remaining_space = config.height - current_y - config.margin * 2 // can't subtract the top-margin because it's in em units...
	#let lines_num = int(remaining_space / config.fontsize / 2)
	#grid(
	    columns: (1fr, 1fr),
	    column-gutter: 6pt,
	    for i in range(lines_num) {
		linebreak()
		box(line(length: 100%, stroke: ruleline))
		linebreak()
	    },
	    for i in range(lines_num) {
		linebreak()
		box(line(length: 100%, stroke: ruleline))
		linebreak()
	    }
	)
    ])

    pagebreak()
}

#if "monthly" in config.include {
    for month in calendar {
	[#monthly-page(month)]
    }
}

/*
** Weekly Pages
*/

#let weekly-page(week) = {
    let d = week.first()
    let d2 = week.last()

    let tabs = (:)
    if "notes" in config.include {
	tabs.insert("Notes", labelize("Notes Index"))
    }
    if "annual" in config.include {
	tabs.insert("Calendar", labelize(d.year))
    }
    tabs.insert("Week " + str(d.week), labelize(d.year, "W" + str(d.week)))

    set page(
	header: header(
	    page-nav([Week #d.week], lbl: labelize(d2.year, "W" + str(d.week))),
	    htab-list(tabs, current: "Week" + str(d.week))
	)
    )

    let quarters = (
	"Q" + str(calc.floor(monthnames.position(mon => {d.name == mon}) / 3 + 1)),
    )
    if d2.year == d.year {
	quarters.push(
	    "Q" + str(calc.floor(monthnames.position(mon => {d2.month == mon}) / 3 + 1)),
	)
    }
    let months = (
	d.name.slice(0, count:3),
    )
    if (d2.year == d.year) {
	months.push(d2.month.slice(0, count:3))
    }
    main-sidebar(quarters: quarters, months: months)

    grid(columns: (1fr, ) * 3, inset: (bottom:8pt, rest: 1pt), column-gutter: 4pt, row-gutter: 0pt, rows: 1fr,
	..week.map(d => {
	    [#d.day. #d.weekday]
	    box(line(length: 100%))
	    for i in range(11) {
		v(1fr)
		line(length:100%, stroke: ruleline)
	    }
	}),
	grid.cell(colspan: 2)[
	    Notes #box(line(length: 100%))
	    #for i in range(11) {
		v(1fr)
		line(length: 100%, stroke: ruleline)
	    }
	]
    )

    pagebreak()
}

#if "weekly" in config.include {
    let prev-week = 0
    for week in chunker(calendar.flatten(), 7) {
	let d = week.first()
	if d.week == prev-week {
	    continue // avoid duplicate weeks from month end/begin overlaps
	}
	prev-week = d.week
	[#weekly-page(week)]
    }
}


/*
** Daily Pages
*/

#let daily-page(day) = {
    let tabs = (:)
    if "notes" in config.include {
	tabs.insert("Notes", labelize("Notes Index"))
    }
    if "annual" in config.include {
	tabs.insert("Calendar", labelize(day.year))
    }
    if "weekly" in config.include {
	tabs.insert("Week " + str(day.week), labelize(day.year, "W" + str(day.week)))
    }
    set page(
	header: header(
	    page-nav([#day.day], lbl: labelize(day.year, day.month, day.day), subtitle: (top: [#day.weekday], bottom: [#day.month])),
	    htab-list(tabs)
	)
    )

    main-sidebar()

    let current-smallmonth = smallmonth(
	include-weeks: "weekly" in config.include,
	calendar.at(monthnames.position(mon => {day.name == mon})),
	current-day: day.day
    )

    style(styles => {
	let size = measure(current-smallmonth,styles)
	grid(
	    columns: (size.width, auto),
	    column-gutter: 6pt,
	    stack(dir: ttb, [
		Schedule
		#box(line(length: 100%, stroke: 1pt))
		#linebreak()
		#for i in range(13) {
		    [#calc.rem((i + 8), 24)]
		    linebreak()
		    box(line(length: 100%, stroke: ruleline))
		    linebreak()
		    linebreak()
		    box(line(length: 100%, stroke: borderline))
		    linebreak()
		}
		#linebreak()

	    ],
		current-smallmonth
	    ),
	    stack(dir: ttb, [
		Top Priorities
		#box(line(length: 100%, stroke: 1pt))
		#for i in range(8) {
		    [#(i+1) ☐]
		    linebreak()
		    box(line(length: 100%, stroke: ruleline))
		}

		#box(stack(spacing: 1fr, dir: ltr, [
		    #box(width: 1fr, htab-list((
			Notes: "https://google.com",  // labelize(day.year, day.month, day.day),
			Reflect: "https://google.com", // labelize(day.year, day.month, day.day, "Reflect")
		    ), current: "Notes"))
		    #box(htab-list((
			"All Notes": "https://google.com",
		    )))
		]))
		#box(line(length: 100%, stroke: 1pt))
		#locate(loc => [
		    #let current_y = loc.position().y
		    #let remaining_space = config.height - current_y - config.margin * 2 // can't subtract the top-margin because it's in em units...
		    #let lines_num = int(remaining_space / config.fontsize / 2)
		    #for i in range(lines_num) {
			linebreak()
			linebreak()
			box(line(length: 100%, stroke: ruleline))
		    }
		    #v(1pt)
		    #box(stack(spacing: 1fr, dir: ltr, [
			#box(width: 1fr, line(length: 100%, stroke: ruleline))
			#link("https://example.com/Notes")[#box()[More...]]
		    ]))
		])
	    ])
	)
    })

    pagebreak()
}

#if "daily" in config.include {
    for day in calendar.flatten().filter(day => day.name == day.month) {
	[#daily-page(day)]
    }
}


/*
** Daily Reflection Pages
*/

#let reflection-page(day) = {
    let tabs = (:)
    if "notes" in config.include {
	tabs.insert("Notes", labelize("Notes Index"))
    }
    if "annual" in config.include {
	tabs.insert("Calendar", labelize(day.year))
    }
    if "weekly" in config.include {
	tabs.insert("Week " + str(day.week), labelize(day.year, "W" + str(day.week)))
    }
    set page(
	header: header(
	    page-nav([#day.day], lbl: labelize(day.year, day.month, day.day, "Reflection"), subtitle: (top: [#day.weekday], bottom: [#day.month])),
	    htab-list(tabs)
	)
    )

    main-sidebar()

    for prompt in config.reflection-prompts {
	prompt
	box(line(length: 100%, stroke: 1pt))
	for i in range(config.reflection-prompt-lines) {
	    linebreak()
	    linebreak()
	    box(line(length: 100%, stroke: ruleline))
	}
	v(0pt)
    }
    [Daily log]
    box(line(length: 100%, stroke: 1pt))
    locate(loc => [
	#let current_y = loc.position().y
	#let remaining_space = config.height - current_y - config.margin * 2 // can't subtract the top-margin because it's in em units...
	#let lines_num = int(remaining_space / config.fontsize / 2) + 1
	#for i in range(lines_num) {
	    linebreak()
	    linebreak()
	    box(line(length: 100%, stroke: ruleline))
	}])

        pagebreak()
}

#if "reflections" in config.include {
    for day in calendar.flatten().filter(day => day.name == day.month) {
	reflection-page(day)
    }
}

/*
** Daily Notes Pages
*/

#let daily-note-page(day) = {
    let tabs = (:)
    if "notes" in config.include {
	tabs.insert("Notes", labelize("Notes Index"))
    }
    if "annual" in config.include {
	tabs.insert("Calendar", labelize(day.year))
    }
    if "weekly" in config.include {
	tabs.insert("Week " + str(day.week), labelize(day.year, "W" + str(day.week)))
    }
    set page(
	header: header(
	    page-nav([#day.day], lbl: labelize(day.year, day.month, day.day, "Notes"), subtitle: (top: [#day.weekday], bottom: [#day.month])),
	    htab-list(tabs)
	)
    )

    main-sidebar()

    locate(loc => [
	#let current_y = loc.position().y
	#let remaining_space = config.height - current_y - config.margin * 2 // can't subtract the top-margin because it's in em units...
	#let lines_num = int(remaining_space / config.fontsize / 2) + 1
	#for i in range(lines_num) {
	    linebreak()
	    linebreak()
	    box(line(length: 100%, stroke: ruleline))
	}])

        pagebreak()
}

#if "daily" in config.include {
    for day in calendar.flatten().filter(day => day.name == day.month) {
	[#daily-note-page(day)]
    }
}

// I'm not sure I need/want these... might be better to just start a quick page in remarkable and just note the i
/*
** Index of Notes
*/
// 3 pages, 01-114

/*
** Note Pages
*/
// 114 pages...
