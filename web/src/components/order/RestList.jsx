"use client";

import { useMemo, useState } from "react";
import { restaurants } from "../../data/restaurants";
import { useRouter } from "next/navigation";
import Restaurant from "./Restaurant";

const SORT_OPTIONS = [
    { id: "distance", label: "Closest" },
    { id: "rating", label: "Best rated" },
    { id: "eta", label: "Fastest" },
    ];

    export default function RestList() {
    const router = useRouter();

    function handleSelectRestaurant(r) {
        router.push(`/restaurants/${r.id}`);
    }

    const [sortBy, setSortBy] = useState("distance");

    const sortedRestaurants = useMemo(() => {
        const copy = [...restaurants];
        switch (sortBy) {
        case "rating":
            return copy.sort((a, b) => b.rating - a.rating);
        case "eta":
            return copy.sort((a, b) => a.etaMin - b.etaMin);
        case "distance":
        default:
            return copy.sort((a, b) => a.distanceMi - b.distanceMi);
        }
    }, [sortBy]);

    function handleSelectRestaurant(r) {
        console.log("Selected restaurant:", r.id);
    }

    return (
        <div className="max-w-2xl mx-auto mt-6">
        <div className="flex justify-between items-center mb-4">
            <h1 className="text-xl font-bold">Restaurants near you</h1>

            <select
            value={sortBy}
            onChange={e => setSortBy(e.target.value)}
            className="border border-gray-300 rounded px-2 py-1 text-sm"
            >
            {SORT_OPTIONS.map(opt => (
                <option key={opt.id} value={opt.id}>
                {opt.label}
                </option>
            ))}
            </select>
        </div>

        {sortedRestaurants.map(r => (
            <Restaurant
            key={r.id}
            restaurant={r}
            onClick={handleSelectRestaurant(r)}
            />
        ))}
        </div>
    );
}
