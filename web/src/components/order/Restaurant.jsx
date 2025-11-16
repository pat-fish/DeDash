"use client";

import { useRouter } from "next/navigation";

export default function RestaurantCard({ restaurant, onClick }) {
        const router = useRouter();
        const handleClick = () => {
        router.push(`/restaurants/${restaurant.id}`);
    };
    return (
        <button
        onClick={handleClick}
        className="w-full text-left border border-brown rounded-lg p-4 mb-3 bg-navy
                    hover:border-purple-500 hover:shadow-sm transition"
        >
        <div className="flex justify-between items-center">
            <div>
            <h2 className="text-lg font-semibold text-silver">{restaurant.name}</h2>
            <p className="text-sm text-silver">{restaurant.cuisine}</p>
            </div>

            <div className="text-right text-sm text-silver">
            <p>{restaurant.distanceMi.toFixed(1)} mi away</p>
            <p>{restaurant.etaMin} min </p>
            <p className="font-medium">⭐ {restaurant.rating}</p>
            </div>
        </div>
        </button>
    );
}
