#!/usr/bin/env python3
import os
import calendar
import argparse
import yaml


def generate_data(year: int, first_weekday: int = 0, start_month: int = 1):
    c = calendar.Calendar(firstweekday=first_weekday)

    # Get the names of the 12 months starting from the given start_month
    months = [
        calendar.month_name[i % 13]
        for i in range(start_month, start_month + 13)
        if calendar.month_name[i % 13]
    ]
    # Generate data for the current year starting from the given start_month
    data = [c.monthdatescalendar(year, i) for i in range(start_month, 13)]
    # Generate data for the next year, if necessary
    data.extend([c.monthdatescalendar(year + 1, i) for i in range(1, start_month)])

    # Construct the data in a more readable format, with the month names and weekday names, each month containing full 7
    # days, even if they are from the previous or next month
    calendar_data = [
        [
            {
                "name": months[i],
                "year": day.year,
                "month": calendar.month_name[day.month],
                "week": day.isocalendar().week,
                "day": day.day,
                "weekday": calendar.day_name[day.weekday()],
            }
            for week in month
            for day in week
        ]
        for i, month in enumerate(data)
    ]

    return calendar_data


def save_data(datafile, data):
    with open(datafile, "w") as f:
        yaml.dump(data, f)


if __name__ == "__main__":
    # Get data needed to handle arguments needed for the generate_data function
    today = calendar.datetime.date.today()
    year = today.year
    months = [calendar.month_abbr[i].lower() for i in range(1, 13)]
    days = [calendar.day_abbr[i].lower() for i in range(7)]

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument("-y", "--year", type=int, default=year, help="Year to generate")
    parser.add_argument(
        "-m", "--start-month", type=str, default="January", help="Month to start from"
    )
    parser.add_argument(
        "-d",
        "--first-weekday",
        type=str,
        default="Monday",
        help="First day of the week",
    )

    args = parser.parse_args()
    start_month = months.index(args.start_month.lower()[:3]) + 1
    first_weekday = days.index(args.first_weekday.lower()[:3])

    calendar_data = generate_data(args.year, first_weekday, start_month)

    datafile = f"calendar_{args.year}.yaml"
    if start_month > 1:
        datafile = f"calendar_{args.year}-{args.year+1}.yaml"

    save_data(datafile, calendar_data)

    # Generate a static symlink to the latest generated datafile for convenience
    linkname = "calendar.yaml"
    try:
        os.remove(linkname)
    except FileNotFoundError:
        pass

    os.symlink(datafile, linkname)
