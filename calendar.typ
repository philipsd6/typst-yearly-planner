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

#let heavyline = line.with(stroke: 1pt + black, length: 100%)
#let ruleline = line.with(stroke: 0.5pt + luma(200), length: 100%)

#let border = 0.5pt + black

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
    margin: if config.toolbar-side == "right" {
	(right: config.margin + config.toolbar-width, top: config.top-margin, rest: config.margin)
    } else {
	(left: config.margin + config.toolbar-width, top: config.top-margin, rest: config.margin)
    },
    header-ascent: config.margin
)


/*
** Utility functions
*/

// Return a label based on the items given
#let labelize(..items) = {
    let key = items.pos().filter(it => {it != none}).map(str).join("-")
    return label(key)
}

/*
** Header/Navigation Functions
*/
#let sideways(body) = {
    return rotate(body, -90deg, reflow: true)
}

#let page-nav(title, lbl: none, title-loc: none, prev: none, next: none, subtitle: none) = {
    let large = text.with(size: 2.8em)
    let small = text.with(size: 1.1em)
    let back(loc) = {return link(loc)[\u{29FC}#h(2pt)]}
    let forward(loc) = {return link(loc)[#h(2pt)\u{29FD}]}

    if lbl == none {
	lbl = labelize(title)
    }

    return grid(columns: 3,
	if prev != none { grid.cell(large()[#back(prev)]) },
	if subtitle == none {
	    // it's just a title, keep it simple
	    grid.cell(if title-loc != none {
		link(title-loc)[#box(large()[#title #lbl])]
	    } else {
		large()[#title #lbl]
	    })
	} else {
	    // more complicated... embed an inner grid
	    let inner-grid = grid(columns: 2, inset: (top: 0pt, bottom: 0pt, rest: 4pt),
		grid.cell(rowspan: 2, stroke: {(right: border)}, large()[#title #lbl]),
		grid.cell(small(weight: "semibold")[#align(top, subtitle.top)]),
		grid.cell(small()[#align(bottom, subtitle.bottom)])
	    )
	    if title-loc != none {
		link(title-loc)[#inner-grid]
	    } else {
		inner-grid
	    }
	},
	if next != none { grid.cell(rowspan: 2, [#large()[#forward(next)]]) },
    )
}

#let header(left-side, right-side) = {
    box(left-side)
    h(1fr)
    box(right-side)
    if config.clear-top-right-corner and config.toolbar-side != "right" {
	box(width: 8mm)
    }
    v(0pt) // (zero vspace still takes up more than without it!)
    box(heavyline())
}


#let tab(body, active: false, ..args) = {
    grid.cell(
	inset: 5pt,
	..args,
	[#metadata((active: active))#body]
    )
}

#show grid.cell: it => {
    let sequence = [*a* _a_].func()
    if it.body.func() == sequence and it.body.children.len() > 0 and it.body.children.first().func() == metadata and it.body.children.last().func() == link {
	let meta = it.body.children.first().value
	let loc = it.body.children.last().dest
	if type(meta) == dictionary and meta.active {
	    return link(loc, box(fill: black, text(fill: white, it)))
	} else {
	    return link(loc, it)
	}
    }
    it
}

#let topbar(size: 1.2em, ..tabs) = {
    tabs = tabs.pos().filter(t => t != none)
    if tabs.len() > 0 {
	return text(size: size, grid(columns: tabs.len(), stroke: (x, y) => if x > 0 {(left: border)},
	    ..tabs
	))
    }
}

#let sidebar(active-tabs: ()) = {
    set text(size: 1.2em)
    let tab = tab.with(inset: (left: 9pt, right: 9pt, rest: 10pt))
    let grid = grid.with(
	inset: 0pt,
	columns: 1,
	stroke: if config.toolbar-side == "right" {
	    (x, y) => (left: border) + if y > 0 {(top: border)}
	} else {
	    (x, y) => (right: border) + if y > 0 {(top: border)}
	}
    )

    let dx = - config.toolbar-width - 2mm
    if config.toolbar-side == "right" {
	dx = config.width - config.toolbar-width
    }
    place(dx: if config.toolbar-side == "right" {
	config.width - config.toolbar-width
    } else {
	- config.toolbar-width - 2mm
    },
	stack(dir: ttb, spacing: 1fr,
	    if "quarterly" in config.include {
		grid(..range(0, 12, step: 3).enumerate(start: 1).map(
		    ((qtr, mon)) => (
			tab(active: "Q"+str(qtr) in active-tabs,
			    link(labelize(calendar.at(mon).first().year, "Q", qtr))[Q#qtr]
			)
		    )
		).map(sideways))
	    },
	    if "monthly" in config.include {
		grid(..calendar.map(month => (
		    tab(active: month.first().name.slice(0, count: 3) in active-tabs,
			link(labelize(month.first().year, month.first().name), month.first().name.slice(0, count: 3))
		    )
		)).map(sideways))
	    }
	)
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
	    cells.push(link(labelize(day.year + if day.week < prev_week { 1 } else { 0 }, "W", day.week))[#day.week])
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
	stroke: (x, y) => if y == 0 {(top: border, bottom: border)} + if include-weeks and x == 0 {(right: border)},
	..cells
    )
}


/*
** Annual calendar page
*/

#let annual-page() = {
    // The title will be the year
    let title = fday.year

    // If the calendar spans a year boundary, use both years as the title.
    let endash = [\u{2013}]
    if fday.year < lday.year {
	title = [#fday.year#endash;#lday.year]
    }

    set page(
	header: header(
	    page-nav(title, lbl: labelize(fday.year)),
	    topbar(
		tab(active: true, link(labelize(fday.year))[Calendar]),
		if "notes" in config.include {

		},
	    )
	)
    )
    

    sidebar()

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
#let quarterly-page(qtr, months, prev: none, next: none) = {
    let year = months.at(0).first().year

    // Adding the following, which does nothing physically to the document causes errors: "label `<2024-Q-1>` does not exist in the document
    // context {
    // 	let newprev = query(heading.where(level: 1, label: <Quarter>).before(here()), inclusive: false)
    // 	let newnext = query(heading.where(level: 1, label: <Quarter>).after(here()), inclusive: false)
    // }

    set page(
	header: header(
	    page-nav([Q#qtr <Quarter>], lbl: labelize(year, "Q", qtr), prev: prev, next: next),
	    topbar(
		if "annual" in config.include {
		    tab(link(labelize(fday.year))[Calendar])
		},
		if "notes" in config.include {
		    tab(link(labelize("Notes Index-1"))[Notes])
		},
	    )
	)
    )

    sidebar(active-tabs: ("Q" + str(qtr), ))

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
		box(ruleline())
	    }
	])
    )

    pagebreak()
}

#if "quarterly" in config.include {
    let prev-range = range(0, 5)
    let next-range = range(2, 6)
    let current-range = range(0, 12, step: 3).enumerate(start: 1)
    for ((pqtr, (qtr, start-month)), nqtr) in prev-range.zip(current-range).zip(next-range) {
	let months = calendar.slice(start-month, count: 3)
	let year = months.first().first().year
	[#quarterly-page(qtr, months,
	    prev: if pqtr != 0 {labelize(year, "Q", pqtr)},
	    next: if nqtr < 5 {labelize(year, "Q", nqtr)})
	]
    }
}


/*
** Monthly Pages
*/


#let monthly-page(month, prev: none, next: none) = {
    let d = month.first()

    set page(
	header: header(
	    page-nav(d.name, lbl: labelize(d.year, d.name), prev: prev, next: next),
	    topbar(
		if "annual" in config.include {
		    tab(link(labelize(fday.year))[Calendar])
		},
		if "notes" in config.include {
		    tab(link(labelize("Notes Index-1"))[Notes])
		},
	    )
	)
    )

    let qtr = calc.floor(monthnames.position(mon => {d.name == mon}) / 3 + 1)
    sidebar(active-tabs: ("Q" + str(qtr), d.name.slice(0, count: 3)))

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
	    cells.push(grid.cell(align: left + horizon, sideways()[#link(labelize(day.year + if day.week < prev_week { 1 } else { 0 }, "W", day.week))[Week#hide[-]#day.week]]))
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
	stroke: (x, y) => {(bottom: border)} + if x > 0 {(left: border)},
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
		box(ruleline())
		linebreak()
	    },
	    for i in range(lines_num) {
		linebreak()
		box(ruleline())
		linebreak()
	    }
	)
    ])

    pagebreak()
}

#if "monthly" in config.include {
    let prev = none
    for (i, month) in calendar.enumerate(start: 1) {
	let next = calendar.at(i, default: (none,)).first()
	[#monthly-page(month,
	    prev: if prev != none {labelize(prev.year, prev.name)},
	    next: if next != none {labelize(next.year, next.name)}
	)]
	prev = month.first()
    }
}

/*
** Weekly Pages
*/

#let weekly-page(week, prev: none, next: none) = {
    let d = week.first()
    let d2 = week.last()

    set page(
	header: header(
	    page-nav([Week #d.week], lbl: labelize(d2.year, "W", d.week), prev: prev, next: next),
	    topbar(
		if "annual" in config.include {
		    tab(link(labelize(fday.year))[Calendar])
		},
		if "notes" in config.include {
		    tab(link(labelize("Notes Index-1"))[Notes])
		},
	    )
	)
    )

    let quarters = (
	"Q" + str(calc.floor(monthnames.position(mon => {d.name == mon}) / 3 + 1)),
    )
    if d2.year == d.year {
	quarters.push(
	    "Q" + str(calc.floor(monthnames.position(mon => {d2.month == mon}) / 3 + 1))
	)
    }
    let months = (
	d.name.slice(0, count:3),
    )
    if (d2.year == d.year) {
	months.push(d2.month.slice(0, count:3))
    }
    sidebar(active-tabs: (quarters + months))

    grid(columns: (1fr, ) * 3, inset: (bottom:8pt, rest: 1pt), column-gutter: 4pt, row-gutter: 0pt, rows: 1fr,
	..week.map(d => {
	    [#d.day. #d.weekday]
	    box(line(length: 100%))
	    for i in range(11) {
		v(1fr)
		ruleline()
	    }
	}),
	grid.cell(colspan: 2)[
	    Notes #box(line(length: 100%))
	    #for i in range(11) {
		v(1fr)
		ruleline()
	    }
	]
    )

    pagebreak()
}

#if "weekly" in config.include {
    let weeks = calendar.flatten().chunks(7)
    let prev = none
    for (i, week) in weeks.enumerate(start: 1) {
	let curr = week.first()
	let next = weeks.at(i, default: (none,)).last()
	if prev != none and curr.week == prev.week {
	    continue // avoid duplicate weeks from month end/begin overlaps
	}
	[#weekly-page(week,
	    prev: if prev != none {labelize(prev.year, "W", prev.week)},
	    next: if next != none {labelize(next.year, "W", next.week)}
	)]
	prev = curr
    }
}


/*
** Daily Pages
*/
#let daily-page(day, prev: none, next: none) = {

    set page(
	header: header(
	    page-nav([#day.day], lbl: labelize(day.year, day.month, day.day), subtitle: (top: [#day.weekday], bottom: [#day.month]), prev: prev, next: next),
	    topbar(
		if "weekly" in config.include {
		    tab(link(labelize(day.year, "W", day.week))[Week #day.week])
		},
		if "annual" in config.include {
		    tab(link(labelize(fday.year))[Calendar])
		},
		if "notes" in config.include {
		    tab(link(labelize("Notes Index-1"))[Notes])
		},
	    )
	)
    )
    let quarter = "Q" + str(calc.floor(monthnames.position(mon => {day.name == mon}) / 3 + 1))
    sidebar(active-tabs: (quarter, day.name.slice(0, count: 3)))

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
		    box(ruleline())
		    linebreak()
		    linebreak()
		    box(line(length: 100%, stroke: border))
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
		    box(ruleline())
		}

		#box(stack(spacing: 1fr, dir: ltr, [
		    #box(width: 1fr,
			topbar(size: 1em,
			    tab(active: true, link(labelize(day.year, day.month, day.day))[Notes]),
			    if "reflections" in config.include {
				tab(link(labelize(day.year, day.month, day.day, "Reflect"))[Reflect])
			    }
			)),
		    #if "notes" in config.include {
			box(tab("All Notes"))
		    }
		]))
		#box(line(length: 100%, stroke: 1pt))
		#locate(loc => [
		    #let current_y = loc.position().y
		    #let remaining_space = config.height - current_y - config.margin * 2 // can't subtract the top-margin because it's in em units...
		    #let lines_num = int(remaining_space / config.fontsize / 2)
		    #for i in range(lines_num - 1) {
			hide([#(i+1)])
			linebreak()
			box(ruleline())
		    }
		    #v(1pt)
		    #box(stack(spacing: 1fr, dir: ltr, [
			#box(width: 1fr, ruleline())
			#link(labelize(day.year, day.month, day.day, "Notes"))[#box()[More...]]
		    ]))
		])
	    ])
	)
    })

    pagebreak()
}

/*
** Daily Notes Pages
*/

#let daily-note-page(day, prev: none, next: none) = {

    set page(
	header: header(
	    page-nav([#day.day], lbl: labelize(day.year, day.month, day.day, "Notes"), subtitle: (top: [#day.weekday], bottom: [#day.month]), prev: prev, next: next, title-loc: labelize(day.year, day.month, day.day)),
	    topbar(
		if "weekly" in config.include {
		    tab(link(labelize(day.year, "W", day.week))[Week #day.week])
		},
		if "annual" in config.include {
		    tab(link(labelize(fday.year))[Calendar])
		},
		if "notes" in config.include {
		    tab(link(labelize("Notes Index-1"))[Notes])
		},
	    )
	)
    )

    let quarter = "Q" + str(calc.floor(monthnames.position(mon => {day.name == mon}) / 3 + 1))
    sidebar(active-tabs: (quarter, day.name.slice(0, count: 3)))

    locate(loc => [
	#let current_y = loc.position().y
	#let remaining_space = config.height - current_y - config.margin * 2 // can't subtract the top-margin because it's in em units...
	#let lines_num = int(remaining_space / config.fontsize / 2) + 1
	#for i in range(lines_num) {
	    linebreak()
	    linebreak()
	    box(ruleline())
	}])

        pagebreak()
}

#if "daily" in config.include {
    let days = calendar.flatten().filter(day => day.name == day.month).slice(0, 2)
    let prev = none
    for (i, day) in days.enumerate(start: 1) {
	let next = days.at(i, default: none)
	daily-page(day,
	    prev: if prev != none { labelize(prev.year, prev.month, prev.day) },
	    next: if next != none { labelize(next.year, next.month, next.day) }
	)
	prev = day
    }
    prev = none
    for (i, day) in days.enumerate(start: 1) {
	let next = days.at(i, default: none)
    	daily-note-page(day,
	    prev: if prev != none { labelize(prev.year, prev.month, prev.day, "Notes") },
	    next: if next != none { labelize(next.year, next.month, next.day, "Notes") }
	)
	prev = day
    }
}

/*
** Daily Reflection Pages
*/

#let reflection-page(day, prev: none, next: none) = {

    set page(
	header: header(
	    page-nav([#day.day], lbl: labelize(day.year, day.month, day.day, "Reflect"), subtitle: (top: [#day.weekday], bottom: [#day.month]), prev: prev, next: next, title-loc: labelize(day.year, day.month, day.day)),
	    topbar(
		if "weekly" in config.include {
		    tab(link(labelize(day.year, "W", day.week))[Week #day.week])
		},
		if "annual" in config.include {
		    tab(link(labelize(fday.year))[Calendar])
		},
		if "notes" in config.include {
		    tab(link(labelize("Notes Index-1"))[Notes])
		},
	    )
	)
    )

    let quarter = "Q" + str(calc.floor(monthnames.position(mon => {day.name == mon}) / 3 + 1))
    sidebar(active-tabs: (quarter, day.name.slice(0, count: 3)))

    for prompt in config.reflection-prompts {
	prompt
	box(line(length: 100%, stroke: 1pt))
	for i in range(config.reflection-prompt-lines) {
	    hide([#1])
	    linebreak()
	    box(ruleline())
	}
	v(0pt)
    }
    [Daily log]
    box(line(length: 100%, stroke: 1pt))
    locate(loc => [
	#let current_y = loc.position().y
	#let remaining_space = config.height - current_y - config.margin * 2 // can't subtract the top-margin because it's in em units...
	#let lines_num = int(remaining_space / config.fontsize / 2) + 1
	#for i in range(lines_num - 1) {
	    hide([#1])
	    linebreak()
	    box(ruleline())
	}])

        pagebreak()
}

#if "reflections" in config.include {
    let days = calendar.flatten().filter(day => day.name == day.month).slice(0, 2)
    let prev = none
    for (i, day) in days.enumerate(start: 1) {
	let next = days.at(i, default: none)
	reflection-page(day,
	    prev: if prev != none {labelize(prev.year, prev.month, prev.day, "Reflect")},
	    next: if next != none {labelize(next.year, next.month, next.day, "Reflect")}
	)
	prev = day
    }
}

/*
** Notes
**
** The number of note pages depends on how many index lines
** fit on the index pages.
*/
#let d = counter("note")

#let index-page(page-num: none, prev: none, next: none) = {

    set page(
	header: header(
	    page-nav([Notes Index], lbl: labelize("Notes Index", page-num),
		prev: if prev != none { labelize("Notes Index", prev) },
		next: if next != none { labelize("Notes Index", next) },
	    ),
	    topbar(
		if "annual" in config.include {
		    tab(link(labelize(fday.year))[Calendar])
		},
		if "notes" in config.include {
		    tab(active: page-num == 1, link(labelize("Notes Index" , 1))[Notes])
		},
	    )
	)
    )

    sidebar()

    locate(loc => {
    	let current_y = loc.position().y
    	let remaining_space = config.height - current_y - config.margin * 2
    	let lines_num = int(remaining_space / config.fontsize / 2)
    	for i in range(lines_num) {
	    d.step()
	    // context {
	    // 	link(labelize("Note", d.get()))[#d.get()]
	    // }
	    context {
		link(labelize("Note", d.get().first()))[#box(width: 1.5em)[#align(right)[#d.get().first()]]]
	    }
    	    linebreak()
    	    box(ruleline())
    	}})

    pagebreak()
}

#let note-page(page-num: 1, prev: none, next: none, thing: none) = {

    set page(
	header: header(
	    page-nav([Note #page-num], lbl: labelize("Note", page-num),
		prev: if prev != none { labelize("Note", prev) },
		next: if next != none { labelize("Note", next) },
	    ),
	    topbar(
		if "annual" in config.include {
		    tab(link(labelize(fday.year))[Calendar])
		},
		if "notes" in config.include {
		    tab(link(labelize("Notes Index", 1))[Notes])
		},
	    )
	)
    )

    sidebar()

    locate(loc => {
    	let current_y = loc.position().y
    	let remaining_space = config.height - current_y - config.margin * 2 // can't subtract the top-margin because it's in em units...
    	let lines_num = int(remaining_space / config.fontsize / 2)
    	for i in range(lines_num) {
	    // [#context d.display()]
    	    // link(labelize("Note", i + j + 1))[#(i + j + 1)]
	    linebreak()
    	    linebreak()
    	    box(ruleline())
    	}})

    pagebreak()
}

#if "notes" in config.include {
    let page-count = 3
    if "note-index-pages" in config {
	page-count = config.note-index-pages
    }
    let prev = none
    let next = none
    for i in range(1, page-count + 1) {
	if i < page-count { next = i + 1 } else { next = none }
	index-page(page-num: i, prev: prev, next: next)
	prev = i
    }

    // context {
    // 	let next = none
    // 	let prev = none
    // 	let notes-count = d.final().at(0)
    // 	for i in range(1, notes-count + 1) {
    // 	    if i < notes-count { next = i + 1 } else { next = none }
    // 	    note-page(page-num: i, prev: prev, next: next)
    // 	    prev = i
    // 	}
    // }
    context {
	let prev = none
	let next = none
	let total = d.final().at(0)
	for i in range(1, total + 1) {
	    if i < total { next = i + 1 } else { next = none }
	    header(
		page-nav([Note #i], lbl: labelize("Note", i),
		    prev: if prev != none { labelize("Note", prev) },
		    next: if next != none { labelize("Note", next) },
		),
	    	topbar(
		    if "annual" in config.include {
			tab(link(labelize(fday.year))[Calendar])
		    },
		    if "notes" in config.include {
			tab(link(labelize("Notes Index", 1))[Notes])
		    },
		)
	    )
	    sidebar()

	    [
		= Note #i #labelize("DupeNote", i)
		== Prev is #prev
		== Next is #next
	    ]
	    prev = i
	    pagebreak()
	}
    }
}
